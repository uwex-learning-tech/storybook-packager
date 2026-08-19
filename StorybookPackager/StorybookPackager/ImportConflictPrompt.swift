//
//  ImportConflictPrompt.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  A slide is either a video or an image with narration audio — never both. A drop can put those two
//  in competition, either by carrying an .mp3 and an .mp4 for the same page number or by landing
//  media on a page that was already authored the other way. Grabbing a folder of narration and
//  forgetting that one slide was authored as a video is easy to do and, before this, silently
//  replaced that video. Ask instead, once, with a row per page.
//

import Cocoa

struct ImportConflict {

    enum Side {
        case video
        case audio
    }

    let pageNumber: String

    let videoName: String
    let audioName: String

    /// The dropped file for each side, or nil when that side is what the presentation already holds.
    let videoURL: URL?
    let audioURL: URL?

    /// Which side the page currently holds, or nil when the drop would create the page.
    let existing: Side?

    var resolution: Side

    /// The dropped file that loses this decision and must not be imported.
    var suppressedURL: URL? {
        return resolution == .video ? audioURL : videoURL
    }

}

extension ImportConflict {

    /// What a page already holds, keyed by its 1-based position — the same key the import derives
    /// from a dropped file name.
    struct ExistingPage {
        let type: String
        let src: String
    }

    /// Find the pages a drop would leave as a video and an image+audio slide at once. Three ways
    /// that happens: the drop carries both an .mp3 and an .mp4 for one page number, it lands
    /// narration on a page authored as video, or it lands a video on a page that already has
    /// narration. Pages the drop only adds to, or that lose nothing, are not conflicts.
    static func detect(droppedURLs: Array<URL>, existingPages: [Int: ExistingPage]) -> [ImportConflict] {

        var audioByPage: [Int: URL] = [:]
        var videoByPage: [Int: URL] = [:]

        for filePath in droppedURLs {

            let ext = Util.shared.canonicalImageExt(filePath.pathExtension)

            guard ext == FileExtensions.MP3 || ext == FileExtensions.MP4 else { continue }

            let parsed = Util.shared.parseNumFromFileName(string: filePath.deletingPathExtension().lastPathComponent)

            // The frame suffix of a bundle image never appears on audio or video, but strip it the
            // same way the import does so the page number is derived identically.
            guard let number = Int(parsed.split(separator: "-").first.map(String.init) ?? "") else { continue }

            // Last one wins within a side, matching how the import itself treats two files claiming
            // the same page — the conflict we are after here is between the two sides.
            if ext == FileExtensions.MP3 {
                audioByPage[number] = filePath
            } else {
                videoByPage[number] = filePath
            }

        }

        return Set(audioByPage.keys).union(videoByPage.keys).sorted().compactMap { number in

            conflict(pageNumber: number,
                     droppedAudio: audioByPage[number],
                     droppedVideo: videoByPage[number],
                     existingPage: existingPages[number])

        }

    }

    private static func conflict(pageNumber: Int,
                                 droppedAudio: URL?,
                                 droppedVideo: URL?,
                                 existingPage: ExistingPage?) -> ImportConflict? {

        // A bundle is narration plus a run of images, so a video landing on one destroys the same
        // authored work an image+audio page would lose.
        let existing: Side?

        switch existingPage?.type {
        case PageTypes.VIDEO:
            existing = .video
        case PageTypes.IMAGE_AUDIO, PageTypes.BUNDLE:
            existing = .audio
        default:
            existing = nil
        }

        let label = Util.shared.formatPageNum(num: pageNumber)
        let source = existingPage?.src ?? ""

        // Both sides dropped at once: whichever the page already is, it can only keep one.
        if let audio = droppedAudio, let video = droppedVideo {

            return ImportConflict(pageNumber: label,
                                  videoName: video.lastPathComponent,
                                  audioName: audio.lastPathComponent,
                                  videoURL: video,
                                  audioURL: audio,
                                  existing: existing,
                                  // Nothing authored to preserve on a new page, and an image with
                                  // narration is far and away the common slide.
                                  resolution: existing ?? .audio)

        }

        if let audio = droppedAudio, existing == .video {

            return ImportConflict(pageNumber: label,
                                  videoName: source + "." + FileExtensions.MP4,
                                  audioName: audio.lastPathComponent,
                                  videoURL: nil,
                                  audioURL: audio,
                                  existing: .video,
                                  resolution: .video)

        }

        if let video = droppedVideo, existing == .audio {

            return ImportConflict(pageNumber: label,
                                  videoName: video.lastPathComponent,
                                  audioName: source + "." + FileExtensions.MP3,
                                  videoURL: video,
                                  audioURL: nil,
                                  existing: .audio,
                                  resolution: .audio)

        }

        return nil

    }

}

enum ImportConflictPrompt {

    /// Ask which side wins for each page. Returns the resolved conflicts, or nil if the user
    /// cancelled — in which case the caller must import nothing at all.
    static func resolve(_ conflicts: [ImportConflict]) -> [ImportConflict]? {

        guard !conflicts.isEmpty else { return conflicts }

        let alert = NSAlert()

        alert.alertStyle = .warning
        alert.messageText = conflicts.count == 1
            ? "One slide can be a video or an image with audio"
            : "\(conflicts.count) slides can be a video or an image with audio"
        alert.informativeText = "A slide is one or the other, so only one of these files can be used for each. Check a slide to use its video; leave it unchecked to use its audio. The file you don't pick is not imported and nothing already in the presentation is replaced by it."

        // Cancel is second so Escape picks it, and it abandons the whole import rather than
        // guessing: a wrong guess here quietly destroys authored work.
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")

        let checkboxes = conflicts.map { conflict -> NSButton in

            let checkbox = NSButton(checkboxWithTitle: rowTitle(for: conflict), target: nil, action: nil)
            checkbox.state = conflict.resolution == .video ? .on : .off
            checkbox.lineBreakMode = .byTruncatingMiddle

            return checkbox

        }

        alert.accessoryView = accessoryView(for: checkboxes)

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        return zip(conflicts, checkboxes).map { conflict, checkbox in

            var resolved = conflict
            resolved.resolution = checkbox.state == .on ? .video : .audio

            return resolved

        }

    }

    private static func rowTitle(for conflict: ImportConflict) -> String {

        func label(_ name: String, isDropped: Bool) -> String {
            return isDropped ? name : "\(name) (already here)"
        }

        let video = label(conflict.videoName, isDropped: conflict.videoURL != nil)
        let audio = label(conflict.audioName, isDropped: conflict.audioURL != nil)

        return "Page \(conflict.pageNumber) — video: \(video)   ·   audio: \(audio)"

    }

    // A scroll view shows whatever sits at its document view's origin, and an ordinary NSView puts
    // that origin at the bottom left — so a long list would open scrolled to the last page rather
    // than the first, hiding the rows the user is most likely to be looking for.
    private final class FlippedView: NSView {
        override var isFlipped: Bool { return true }
    }

    // Internal rather than private so a test can check the list is built top-down.
    static func accessoryView(for checkboxes: [NSButton]) -> NSView {

        let stack = NSStackView(views: checkboxes)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let width: CGFloat = 460
        let contentHeight = stack.fittingSize.height

        // A drop can conflict on many pages at once; past a screenful the list has to scroll rather
        // than grow the alert off the top of the display.
        guard contentHeight > 220 else {

            stack.frame = NSRect(x: 0, y: 0, width: width, height: contentHeight)
            stack.translatesAutoresizingMaskIntoConstraints = true

            return stack

        }

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: 220))

        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let documentView = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: contentHeight))
        documentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])

        scrollView.documentView = documentView

        return scrollView

    }

}
