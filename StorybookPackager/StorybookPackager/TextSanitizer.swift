//
//  TextSanitizer.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

// Trims the leading/trailing whitespace and newlines that ride along when text is pasted in from
// Word, a PDF, or a browser. Interior formatting -- blank lines, indentation, HTML markup -- is
// left exactly as typed.
enum TextSanitizer {

    static func sanitized(_ string: String) -> String {
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

extension NSTextField {

    // Trims the displayed value in place and returns what the caller should commit, so the model and
    // the field can never disagree. Writes back only on an actual change to avoid a needless redraw.
    @discardableResult func sanitize() -> String {

        let clean = TextSanitizer.sanitized(stringValue)

        if clean != stringValue {
            stringValue = clean
        }

        return clean

    }

}

extension NSTextView {

    @discardableResult func sanitize() -> String {

        let clean = TextSanitizer.sanitized(string)

        if clean != string {
            string = clean
        }

        return clean

    }

}
