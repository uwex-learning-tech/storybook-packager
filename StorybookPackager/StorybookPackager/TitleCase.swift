//
//  TitleCase.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  A Swift port of John Gruber's Title Case script, by way of Aristotle Pagaltzis' refactoring at
//  https://github.com/ap/titlecase (MIT licensed). The regular expressions and the order they are
//  applied in are the original's; only the substitution mechanics are rewritten, because ICU has no
//  equivalent of Perl's \u and \L case operators inside a replacement template.
//
//  Copyright © 2008 John Gruber, © 2008 Aristotle Pagaltzis. MIT (X11) License.
//

import Foundation

enum TitleCase {

    // An optional possessive or contraction tail, so "Apple's" is treated as one word.
    private static let apos = "(?:['’]\\p{Ll}*)?"

    // Words a copy editor leaves lowercase mid-title. "a" is excluded after "q&" and "at" before
    // "&t", so "Q&A" and "AT&T" survive as acronyms rather than being recased.
    private static let small = "(?<!q&)a|an|and|as|at(?!&t)|but|by|en|for|if|in|of|on|or|the|to|v[.]?|via|vs[.]?"

    private static let punct = "[\\p{P}\\p{S}]"

    // One pass over every word. The branches are ordered, and which one matched decides the casing:
    // a path/URL/number is preserved, a small word is lowercased, a word without internal capitals is
    // capitalized, and anything else (iPhone, HTML) keeps the spelling the author typed. Leading and
    // trailing underscores are captured separately so Markdown emphasis survives.
    private static let wordPattern =
        "\\b(_*)(?:"
        + "((?<=[\\x20][/\\\\])\\p{L}+[-_\\p{L}/\\\\]+"          // file path
        + "|[-_\\p{L}]+[@.:][-_\\p{L}@.:/]+" + apos              // URL, domain, or email
        + "|[0-9][0-9,._\\x20]+" + apos + ")"                    // numeric literal
        + "|((?i:" + small + ")" + apos + ")"                    // small word
        + "|(\\p{L}[\\p{Ll}'’()\\[\\]{}]*" + apos + ")"          // word without internal capitals
        + "|(\\p{L}[\\p{L}'’()\\[\\]{}]*" + apos + ")"           // any other word
        + ")(_*)\\b"

    // A small word is capitalized when it opens the title, a subsentence, or an inserted subphrase.
    private static let openingPattern =
        "(\\A" + punct + "*|[:.;?!][\\x20]+|[\\x20]['\"“‘(\\[][\\x20]*)(" + small + ")\\b"

    // ... and when it closes the title or an inserted subphrase.
    private static let closingPattern =
        "\\b(" + small + ")(?=" + punct + "*\\z|['\"’”)\\]][\\x20])"

    // In a hyphenated compound the small word is capitalized: "In-Flight", "Stand-In". The lookarounds
    // for further hyphens keep "man-in-the-middle" intact.
    private static let beforeHyphenPattern = "\\b(?<!-)(" + small + ")(?=-\\p{L}+)"
    private static let afterHyphenPattern = "\\b(\\p{L}+-)(" + small + ")(?!-)"

    static func titleCased(_ string: String) -> String {

        var result = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // A title with no lowercase letter at all is shouting, not a collection of acronyms.
        if !result.contains(where: { $0.isLowercase }) {
            result = result.lowercased()
        }

        result = rewrite(result, wordPattern, []) { groups in

            let core: String

            if let preserved = groups[2] {
                core = preserved
            } else if let smallWord = groups[3] {
                core = smallWord.lowercased()
            } else if let plainWord = groups[4] {
                core = capitalize(plainWord)
            } else {
                core = groups[5] ?? ""
            }

            return (groups[1] ?? "") + core + (groups[6] ?? "")

        }

        result = rewrite(result, openingPattern, [.caseInsensitive]) { groups in
            (groups[1] ?? "") + capitalize(groups[2] ?? "")
        }

        result = rewrite(result, closingPattern, [.caseInsensitive]) { groups in
            capitalize(groups[1] ?? "")
        }

        result = rewrite(result, beforeHyphenPattern, [.caseInsensitive]) { groups in
            capitalize(groups[1] ?? "")
        }

        // The word before the hyphen was already cased by an earlier pass, so it is copied through.
        result = rewrite(result, afterHyphenPattern, [.caseInsensitive]) { groups in
            (groups[1] ?? "") + upperFirst(groups[2] ?? "")
        }

        return result

    }

    // Replaces every match, handing the capture groups to `body` as an index-addressable array whose
    // numbering lines up with the Perl original's $1...$6. Unmatched groups arrive as nil.
    private static func rewrite(_ string: String,
                                _ pattern: String,
                                _ options: NSRegularExpression.Options,
                                _ body: ([String?]) -> String) -> String {

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            assertionFailure("TitleCase pattern failed to compile: \(pattern)")
            return string
        }

        let source = string as NSString
        var result = ""
        var cursor = 0

        for match in regex.matches(in: string, range: NSRange(location: 0, length: source.length)) {

            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))

            let groups = (0..<match.numberOfRanges).map { index -> String? in
                let range = match.range(at: index)
                return range.location == NSNotFound ? nil : source.substring(with: range)
            }

            result += body(groups)
            cursor = match.range.location + match.range.length

        }

        return result + source.substring(from: cursor)

    }

    private static func capitalize(_ word: String) -> String {
        return upperFirst(word.lowercased())
    }

    private static func upperFirst(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }

}
