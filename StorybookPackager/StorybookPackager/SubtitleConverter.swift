//
//  SubtitleConverter.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  Turns a dropped caption file into the WebVTT bytes the Storybook+ player reads. A .vtt file is
//  passed through (normalized only); a .srt file is converted — SubRip's comma decimal separator,
//  cue numbers, and player-specific markup are all things a <track> element chokes on.
//

import Foundation

enum SubtitleConverter {

    enum ConversionError: Error {

        /// The bytes could not be decoded as text in any encoding subtitle files are written in.
        case unreadable

        /// The file decoded fine but held no timed cue — an empty or non-caption file.
        case noCues

    }

    /// Read a caption file from disk and return it as WebVTT bytes (always UTF-8).
    static func webVTTData(contentsOf url: URL) throws -> Data {

        guard let data = try? Data(contentsOf: url) else { throw ConversionError.unreadable }
        guard let text = decodeText(data) else { throw ConversionError.unreadable }

        return Data(try webVTT(fromSubtitleText: text).utf8)

    }

    /// Convert decoded subtitle text to WebVTT. Text that is already valid WebVTT is left alone
    /// apart from line-ending and BOM normalization — it may hold cue identifiers, NOTE, STYLE and
    /// REGION blocks that a cue-by-cue rewrite would throw away. Anything else is read as SubRip.
    static func webVTT(fromSubtitleText text: String) throws -> String {

        let normalized = normalize(text)

        if hasWebVTTSignature(normalized) && containsWebVTTTiming(normalized) {
            return normalized.hasSuffix("\n") ? normalized : normalized + "\n"
        }

        return try convertSubRip(normalized)

    }

    // MARK: - WebVTT recognition

    /// The signature is the word WEBVTT followed by end-of-line or a space — a browser rejects the
    /// whole file if the seventh character is anything else, so this is not merely a prefix check.
    private static func hasWebVTTSignature(_ text: String) -> Bool {

        guard text.hasPrefix("WEBVTT") else { return false }

        let rest = text.dropFirst("WEBVTT".count)

        guard let next = rest.first else { return true }

        return next == " " || next == "\t" || next == "\n"

    }

    // A browser skips any cue whose timing line it cannot parse, so a file carrying the signature
    // but no parseable timing loads as an empty track — captions silently missing, no error anywhere.
    // Requiring one real timing line sends those down the SubRip path to be repaired instead: a
    // hand-written WEBVTT header pasted on top of an unconverted .srt is exactly what people try.
    private static let webVTTTimingRegex = try! NSRegularExpression(
        pattern: "^(?:\\d{2,}:)?[0-5]\\d:[0-5]\\d\\.\\d{3}[ \t]+-->[ \t]+(?:\\d{2,}:)?[0-5]\\d:[0-5]\\d\\.\\d{3}",
        options: [.anchorsMatchLines]
    )

    private static func containsWebVTTTiming(_ text: String) -> Bool {
        return webVTTTimingRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    // MARK: - decoding

    /// Decode subtitle bytes. SubRip files in the wild are UTF-8, UTF-16 (from Windows tools), or a
    /// single-byte Windows/Latin encoding; the last of those always succeeds, so mojibake is the
    /// worst case rather than a failed import.
    static func decodeText(_ data: Data) -> String? {

        let bytes = [UInt8](data.prefix(3))

        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) {
            if let text = String(data: data, encoding: .utf16) { return text }
        }

        for encoding in [String.Encoding.utf8, .windowsCP1252, .isoLatin1] {
            if let text = String(data: data, encoding: encoding) { return text }
        }

        return nil

    }

    // MARK: - SubRip conversion

    private struct Cue {
        var start: String
        var end: String
        var settings: String
        var lines: [String] = []
    }

    private static func convertSubRip(_ text: String) throws -> String {

        var cues: [Cue] = []
        var current: Cue?

        func flush() {

            defer { current = nil }

            guard var cue = current else { return }

            // Trailing blank payload lines are noise; a cue whose payload is empty after markup is
            // stripped carries nothing for the player to show.
            while let last = cue.lines.last, last.isEmpty { cue.lines.removeLast() }
            guard !cue.lines.isEmpty else { return }

            cues.append(cue)

        }

        let lines = text.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {

            // A timing line always opens a cue, whether or not the previous one was closed by a
            // blank line — some files run cues together.
            if let timing = parseTiming(line) {
                flush()
                current = Cue(start: timing.start, end: timing.end, settings: timing.settings)
                continue
            }

            if line.trimmingCharacters(in: .whitespaces).isEmpty {

                // Only a blank line *after* the cue's text ends it. A blank line between the timing
                // line and the text is a sloppy exporter's doing; closing the cue there would throw
                // away an empty cue and then strand its text with nothing to attach to.
                if current?.lines.isEmpty == false { flush() }

                continue

            }

            // Anything before the first timing line of a cue is SubRip's cue number (or a stray
            // header). VTT has no use for it: cue identifiers are optional and these carry nothing.
            guard current != nil else { continue }

            // The same number, in a file that ran the cues together without a blank line between
            // them. Read as text it would show up on screen as a stray digit in the previous cue.
            if isCueNumber(line), index + 1 < lines.count, parseTiming(lines[index + 1]) != nil {
                continue
            }

            current!.lines.append(sanitize(line))

        }

        flush()

        guard !cues.isEmpty else { throw ConversionError.noCues }

        var out = "WEBVTT\n"

        for cue in cues {
            out += "\n"
            out += cue.settings.isEmpty ? "\(cue.start) --> \(cue.end)\n" : "\(cue.start) --> \(cue.end) \(cue.settings)\n"
            out += cue.lines.joined(separator: "\n") + "\n"
        }

        return out

    }

    private static func isCueNumber(_ line: String) -> Bool {

        let trimmed = line.trimmingCharacters(in: .whitespaces)

        return !trimmed.isEmpty && trimmed.allSatisfy { $0.isASCII && $0.isNumber }

    }

    // MARK: - timings

    // Hours are optional (some tools emit MM:SS), the decimal separator is a comma in SubRip and a
    // period in VTT, and the arrow is occasionally written with the wrong number of dashes.
    private static let timingRegex = try! NSRegularExpression(
        pattern: "^\\s*(?:(\\d{1,4}):)?(\\d{1,3}):(\\d{1,2})[,.](\\d{1,3})\\s*-{1,3}>\\s*(?:(\\d{1,4}):)?(\\d{1,3}):(\\d{1,2})[,.](\\d{1,3})\\s*(.*?)\\s*$"
    )

    private static func parseTiming(_ line: String) -> (start: String, end: String, settings: String)? {

        let range = NSRange(line.startIndex..., in: line)
        guard let match = timingRegex.firstMatch(in: line, range: range) else { return nil }

        func group(_ index: Int) -> String {
            guard let r = Range(match.range(at: index), in: line) else { return "" }
            return String(line[r])
        }

        let start = timecode(hours: group(1), minutes: group(2), seconds: group(3), fraction: group(4))
        let end = timecode(hours: group(5), minutes: group(6), seconds: group(7), fraction: group(8))

        return (start, end, cueSettings(group(9)))

    }

    private static func timecode(hours: String, minutes: String, seconds: String, fraction: String) -> String {

        // The fraction is a decimal fraction of a second, so a short one pads on the right (",5" is
        // half a second, not five milliseconds); everything else pads on the left.
        let millis = String((fraction + "000").prefix(3))

        return "\(pad(hours.isEmpty ? "0" : hours)):\(pad(minutes)):\(pad(seconds)).\(millis)"

    }

    private static func pad(_ value: String) -> String {
        return value.count >= 2 ? value : String(repeating: "0", count: 2 - value.count) + value
    }

    private static let settingKeys = ["vertical", "line", "position", "size", "align", "region"]

    /// Keep only real VTT cue settings from whatever trails the arrow. SubRip files often carry
    /// display coordinates there ("X1:040 X2:600 Y1:050 Y2:100"), which VTT rejects as malformed.
    private static func cueSettings(_ trailing: String) -> String {

        let tokens: [String] = trailing.split(separator: " ").compactMap { token in

            let parts = token.split(separator: ":", maxSplits: 1)

            guard parts.count == 2, settingKeys.contains(parts[0].lowercased()) else { return nil }

            // The key is a VTT keyword, and a browser only recognizes it in lower case — matching
            // "ALIGN:middle" and then emitting it unchanged would keep the setting from applying.
            return parts[0].lowercased() + ":" + parts[1]

        }

        return tokens.joined(separator: " ")

    }

    // MARK: - payload

    private static func sanitize(_ line: String) -> String {

        var text = line

        // ASS/SSA override blocks ({\an8}, {\pos(…)}) are a SubRip player extension with no VTT
        // equivalent; drop the block, keep the words around it.
        text = replacingMatches(in: text, pattern: "\\{\\\\[^}]*\\}", with: "")

        // <font> is not one of VTT's cue tags — a player renders it as literal text. Drop the tag
        // and keep its contents.
        text = replacingMatches(in: text, pattern: "(?i)</?font[^>]*>", with: "")

        text = escape(text)

        return text.trimmingCharacters(in: .whitespaces)

    }

    /// Escape the two characters VTT treats as markup, leaving alone anything that is already an
    /// entity or one of the cue tags VTT does understand.
    private static func escape(_ line: String) -> String {

        var text = replacingMatches(
            in: line,
            pattern: "&(?!(?:[a-zA-Z][a-zA-Z0-9]*|#[0-9]+|#[xX][0-9a-fA-F]+);)",
            with: "&amp;"
        )

        text = replacingMatches(
            in: text,
            pattern: "<(?!/?(?:b|i|u|c|v|lang|ruby|rt)(?:[ .>]|/>))",
            with: "&lt;"
        )

        return text

    }

    private static func replacingMatches(in text: String, pattern: String, with template: String) -> String {

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )

    }

    // MARK: - normalization

    private static func normalize(_ text: String) -> String {

        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")

        // A byte-order mark decoded into the string would sit in front of the WEBVTT signature and
        // keep the player from recognizing the file.
        while normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)

    }

}
