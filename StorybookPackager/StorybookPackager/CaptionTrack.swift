//
//  CaptionTrack.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  One slide's captions, parsed far enough to show them while the slide plays in the editor.
//  SubtitleConverter already turns whatever was dropped in into WebVTT; this reads that WebVTT back
//  as timed cues, so the editor renders them itself rather than handing the file to a player that
//  would need a real track, a real URL, and a real asset composition to display it.
//
//  Only slides whose media the presentation itself holds can carry captions: an image with
//  narration, a bundle, or a video. A Kaltura, YouTube, or Vimeo slide plays a video hosted
//  elsewhere and takes its captions from there.
//

import Foundation

struct CaptionTrack {

    struct Cue: Equatable {
        let start: TimeInterval
        let end: TimeInterval
        let text: String
    }

    let cues: [Cue]

    /// Reads the cues out of a WebVTT file. Fails when the text holds no cue at all — an empty
    /// track and a track that could not be read are the same thing to a caller, and neither is
    /// worth putting an empty caption bar on screen for.
    init?(webVTT text: String) {

        var cues: [Cue] = []
        var lines = CaptionTrack.normalize(text).components(separatedBy: "\n")

        // A cue is a timing line followed by its payload, so walk the file rather than splitting on
        // blank lines: the identifier line above a timing line, and NOTE/STYLE blocks, are skipped
        // by simply never matching.
        while !lines.isEmpty {

            let line = lines.removeFirst()

            guard let timing = CaptionTrack.timing(line) else { continue }

            var payload: [String] = []

            while let next = lines.first, !next.trimmingCharacters(in: .whitespaces).isEmpty {
                payload.append(lines.removeFirst())
            }

            let body = CaptionTrack.plainText(payload.joined(separator: "\n"))

            guard !body.isEmpty, timing.end > timing.start else { continue }

            cues.append(Cue(start: timing.start, end: timing.end, text: body))

        }

        guard !cues.isEmpty else { return nil }

        self.cues = cues.sorted { $0.start < $1.start }

    }

    /// The cue covering this moment, or nil between cues. A cue's end is exclusive so two adjacent
    /// cues never both claim the instant they meet at.
    func text(at time: TimeInterval) -> String? {
        return cues.first { time >= $0.start && time < $0.end }?.text
    }

    // MARK: - which slides have captions at all

    /// The slide types the editor stores captions for, mapped to the asset directory they live in
    /// beside the media they caption.
    static func assetDirectory(forPageType type: String) -> String? {

        switch type {
        case PageTypes.IMAGE_AUDIO, PageTypes.BUNDLE:
            return FileNames.AUDIO_DIR
        case PageTypes.VIDEO:
            return FileNames.VIDEO_DIR
        default:
            return nil
        }

    }

    static func supportsCaptions(pageType type: String) -> Bool {
        return assetDirectory(forPageType: type) != nil
    }

    /// What the caption file for a slide is called. Captions are named for the slide, not for a
    /// frame within it: a bundle's images are "…03-1", "…03-2", but its captions are "…03".
    static func fileName(forPageSource src: String) -> String {
        return "\(src).\(FileExtensions.VTT)"
    }

    // MARK: - parsing

    private static func normalize(_ text: String) -> String {

        return text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

    }

    /// "00:01:02.500 --> 00:01:05.000 line:90%" — the cue settings after the end time are the
    /// player's business, not ours.
    private static func timing(_ line: String) -> (start: TimeInterval, end: TimeInterval)? {

        guard line.contains("-->") else { return nil }

        let sides = line.components(separatedBy: "-->")

        guard sides.count == 2,
              let start = seconds(sides[0].trimmingCharacters(in: .whitespaces)),
              let end = seconds(sides[1].trimmingCharacters(in: .whitespaces)
                                        .components(separatedBy: .whitespaces)[0]) else { return nil }

        return (start, end)

    }

    /// WebVTT writes either "HH:MM:SS.mmm" or "MM:SS.mmm".
    private static func seconds(_ timecode: String) -> TimeInterval? {

        let parts = timecode.components(separatedBy: ":")

        guard (2...3).contains(parts.count) else { return nil }

        var total: TimeInterval = 0

        // Double() would also read "0x10" and a leading sign; a timecode field is digits and at
        // most one decimal separator, and anything else means this is not a timing line.
        func field(_ text: String) -> TimeInterval? {

            let value = text.replacingOccurrences(of: ",", with: ".")

            guard !value.isEmpty,
                  value.allSatisfy({ $0.isNumber || $0 == "." }),
                  value.filter({ $0 == "." }).count <= 1 else { return nil }

            return Double(value)

        }

        for part in parts.dropLast() {
            guard let value = field(part) else { return nil }
            total = total * 60 + value
        }

        guard let last = field(parts[parts.count - 1]) else { return nil }

        return total * 60 + last

    }

    /// Cue payload as a person reads it: the markup a caption file carries — voice spans, bold and
    /// italic tags, timestamp tags — is not something a plain label can render, and showing it raw
    /// is worse than showing none of it.
    private static func plainText(_ payload: String) -> String {

        var text = payload.replacingOccurrences(of: "<[^>]*>",
                                                with: "",
                                                options: .regularExpression)

        // The converter escapes these on the way in, so they come back out here. Ampersand last, or
        // it would decode the entities the other replacements just produced.
        for (entity, character) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " "), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: character)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)

    }

}
