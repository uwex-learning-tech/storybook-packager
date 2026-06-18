//
//  CalculateLengthDialogController.swift
//  Storybook Packager
//
//  Estimates the presentation Length by summing the real durations of the pages we can measure —
//  narrated/audio and local-video pages (read locally), plus Vimeo (oEmbed), Kaltura (HLS
//  playManifest), and YouTube (scraped from the watch page) streaming pages (read over the
//  network) — and a per-page fallback for everything else (image-only, quizzes, HTML). The result
//  is formatted as whole minutes ("<n> min") and handed back to the Properties dialog through a
//  completion handler.
//

import Cocoa
import AVFoundation
import SbXmlParser

struct CalculateLengthResult {
    var OK = false
    var CANCEL = false
    var lengthString = ""
}

class CalculateLengthDialogController: NSViewController {

    @IBOutlet weak var defaultSecondsTxtfld: NSTextField!
    @IBOutlet weak var resultLbl: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var calculateBtn: NSButton!
    @IBOutlet weak var saveBtn: NSButton!

    // the default fallback duration (in seconds) for slides we can't measure
    private let defaultFallbackSeconds = 30

    private var doc: Document?
    private var computedLength = ""

    // bounded session so a slow/unreachable streaming lookup can't hang the spinner indefinitely
    private let networkSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        return URLSession(configuration: config)
    }()

    var result = CalculateLengthResult()
    var completionHandler: ((CalculateLengthResult) -> ())?

    override func viewDidLoad() {
        super.viewDidLoad()

        // seed the fallback field with the default each time the dialog opens (only ints allowed)
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.allowsFloats = false
        defaultSecondsTxtfld.formatter = formatter
        defaultSecondsTxtfld.integerValue = defaultFallbackSeconds

        resultLbl.stringValue = ""
        progressIndicator.isHidden = true
        progressIndicator.usesThreadedAnimation = true
        saveBtn.isEnabled = false
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        doc = NSDocumentController.shared.currentDocument as? Document
    }

    @IBAction func calculate(_ sender: NSButton) {

        self.view.window?.makeFirstResponder(nil)

        // read the fallback seconds, defaulting to 30 on empty/invalid input
        var fallbackSeconds = defaultSecondsTxtfld.integerValue
        if defaultSecondsTxtfld.stringValue.isEmpty || fallbackSeconds < 0 {
            fallbackSeconds = defaultFallbackSeconds
            defaultSecondsTxtfld.integerValue = fallbackSeconds
        }

        guard let pages = doc?.getXmlObjPages() else { return }

        // measuring durations (local files + streaming lookups) can be slow, so run off the main queue
        calculateBtn.isEnabled = false
        saveBtn.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)

        let fallback = Double(fallbackSeconds)

        DispatchQueue.global(qos: .userInitiated).async {

            // streaming lookups (vimeo/kaltura) are async, so fan them out and wait for the group;
            // a lock guards the running total since completions land on arbitrary threads
            let group = DispatchGroup()
            let lock = NSLock()
            var totalSeconds: Double = 0

            func accumulate(_ seconds: Double) {
                lock.lock()
                totalSeconds += seconds
                lock.unlock()
            }

            for page in pages {

                switch page.type {

                case PageTypes.IMAGE_AUDIO, PageTypes.BUNDLE:
                    accumulate(self.audioDuration(src: page.src) ?? fallback)

                case PageTypes.VIDEO:
                    accumulate(self.videoDuration(src: page.src) ?? fallback)

                case PageTypes.SECTION:
                    break // divider, not a content page

                case PageTypes.VIMEO:
                    group.enter()
                    self.vimeoDuration(src: page.src) { seconds in
                        accumulate(seconds ?? fallback)
                        group.leave()
                    }

                case PageTypes.KALTURA:
                    group.enter()
                    self.kalturaDuration(src: page.src) { seconds in
                        accumulate(seconds ?? fallback)
                        group.leave()
                    }

                case PageTypes.YOUTUBE:
                    group.enter()
                    self.youtubeDuration(src: page.src) { seconds in
                        accumulate(seconds ?? fallback)
                        group.leave()
                    }

                default:
                    // image, all quiz types, html
                    accumulate(fallback)

                }

            }

            // backstop in case a streaming completion never fires; per-request timeouts make this rare
            _ = group.wait(timeout: .now() + 60)

            let lengthString = self.formattedLength(totalSeconds: totalSeconds)

            DispatchQueue.main.async {
                self.computedLength = lengthString
                self.resultLbl.stringValue = lengthString
                self.progressIndicator.stopAnimation(nil)
                self.progressIndicator.isHidden = true
                self.calculateBtn.isEnabled = true
                self.saveBtn.isEnabled = true
            }

        }

    }

    @IBAction func save(_ sender: NSButton) {
        result.OK = true
        result.CANCEL = false
        result.lengthString = computedLength
        completionHandler?(result)
    }

    @IBAction func cancel(_ sender: NSButton) {
        result.OK = false
        result.CANCEL = true
        completionHandler?(result)
    }

    // MARK: - Local media

    // Read a local narration track (assets/audio/<src>.mp3) from the in-memory FileWrapper.
    private func audioDuration(src: String) -> Double? {

        guard !src.isEmpty,
              let wrapper = doc?.getAssetFileWrapper(name: "\(src).\(FileExtensions.MP3)", at: FileNames.AUDIO_DIR),
              let data = wrapper.regularFileContents else { return nil }

        guard let player = try? AVAudioPlayer(data: data) else { return nil }

        return validSeconds(player.duration)

    }

    // Read a local video (assets/video/<src>.mp4). AVURLAsset needs a URL, so spill the wrapper's
    // bytes to a temp file (works whether or not the document has been saved to disk), measure,
    // then clean up.
    private func videoDuration(src: String) -> Double? {

        guard !src.isEmpty,
              let wrapper = doc?.getAssetFileWrapper(name: "\(src).\(FileExtensions.MP4)", at: FileNames.VIDEO_DIR),
              let data = wrapper.regularFileContents else { return nil }

        let tempUrl = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(FileExtensions.MP4)

        do {
            try data.write(to: tempUrl)
        } catch {
            return nil
        }

        defer { try? FileManager.default.removeItem(at: tempUrl) }

        let asset = AVURLAsset(url: tempUrl)
        return validSeconds(CMTimeGetSeconds(asset.duration))

    }

    // MARK: - Streaming media

    // Vimeo exposes the real duration (in seconds) through its public oEmbed endpoint — no API key.
    private func vimeoDuration(src: String, completion: @escaping (Double?) -> ()) {

        guard !src.isEmpty,
              let url = URL(string: "https://vimeo.com/api/oembed.json?url=https://vimeo.com/\(src)") else {
            completion(nil)
            return
        }

        networkSession.dataTask(with: url) { data, _, _ in

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let seconds = (json["duration"] as? NSNumber)?.doubleValue else {
                completion(nil)
                return
            }

            completion(self.validSeconds(seconds))

        }.resume()

    }

    // Kaltura's oEmbed doesn't expose duration, but its HLS playManifest does. Build the same URL the
    // player uses (from the stored partner/flavor IDs) and let AVURLAsset read the stream's duration.
    private func kalturaDuration(src: String, completion: @escaping (Double?) -> ()) {

        guard !src.isEmpty,
              let partnerId = UserDefaults.standard.string(forKey: Preferences.KALTURA_PARTNER_ID),
              let flavorId = UserDefaults.standard.string(forKey: Preferences.KALTURA_FLAVOR_ID),
              let url = URL(string: "https://cdnapisec.kaltura.com/p/\(partnerId)/sp/0/playManifest/entryId/\(src)/format/applehttp/protocol/https/flavorParamId/\(flavorId)/video.mp4") else {
            completion(nil)
            return
        }

        let asset = AVURLAsset(url: url)

        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError?
            guard asset.statusOfValue(forKey: "duration", error: &error) == .loaded else {
                completion(nil)
                return
            }
            completion(self.validSeconds(CMTimeGetSeconds(asset.duration)))
        }

    }

    // YouTube's oEmbed has no duration, so scrape the watch page for the "lengthSeconds" value its
    // player markup embeds. Best-effort: YouTube can change this markup or serve a consent page, so
    // any miss falls back rather than failing the whole calculation.
    private func youtubeDuration(src: String, completion: @escaping (Double?) -> ()) {

        guard !src.isEmpty,
              let url = URL(string: "https://www.youtube.com/watch?v=\(src)") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        // a desktop User-Agent nudges YouTube to return the player markup instead of a consent/redirect page
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        networkSession.dataTask(with: request) { data, _, _ in

            guard let data = data,
                  let html = String(data: data, encoding: .utf8),
                  let seconds = Self.parseLengthSeconds(from: html) else {
                completion(nil)
                return
            }

            completion(self.validSeconds(seconds))

        }.resume()

    }

    // MARK: - Helpers

    // Pull the first "lengthSeconds" value out of YouTube watch-page HTML. Tolerant of the quoting and
    // escaping variants the markup uses (e.g. "lengthSeconds":"212" or \"lengthSeconds\":\"212\").
    static func parseLengthSeconds(from html: String) -> Double? {

        guard let regex = try? NSRegularExpression(pattern: "lengthSeconds[\\\\\":]+([0-9]+)") else { return nil }

        let range = NSRange(html.startIndex..., in: html)

        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: html) else { return nil }

        return Double(html[captureRange])

    }

    // Treat 0/NaN/negative as "couldn't measure" so the caller falls back instead of undercounting.
    private func validSeconds(_ seconds: Double) -> Double? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }

    // Whole minutes, rounded up — e.g. 43 min. Centralized so the output format is unit-testable.
    func formattedLength(totalSeconds: Double) -> String {
        return "\(Int(ceil(totalSeconds / 60))) min"
    }

}
