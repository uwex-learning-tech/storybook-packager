//
//  ReleaseYear.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  The release year has no independent representation in sbplus.xml — StorybookXml.toString() emits
//  only `program` and `course`, and the year rides along as an `_r<2-digit year>` suffix on `course`
//  (e.g. course="apc472_r26"). The Storybook+ player reads that string, so it must keep its exact
//  shape. This is the one place the suffix is built or read; nothing else should hand-roll it.
//

import Foundation

enum ReleaseYear {

    static let range = 2017...2037

    // The menu item shown when a document has no year yet, so opening Properties never silently
    // assigns one.
    static let placeholderTitle = "—"

    static var current: Int {
        let year = Calendar.current.component(.year, from: Date())
        return min(max(year, range.lowerBound), range.upperBound)
    }

    static var titles: [String] {
        return range.map { String($0) }
    }

    // 2026 -> "26". Two digits suffice for 2017–2037.
    static func suffix(for year: Int) -> String {
        return String(year % 100)
    }

    // "26" or "r26" -> 2026. Also accepts a full "2026".
    static func year(fromSuffix suffix: String) -> Int? {

        var digits = suffix

        if digits.hasPrefix("r") || digits.hasPrefix("R") {
            digits.removeFirst()
        }

        guard !digits.isEmpty, digits.allSatisfy({ $0.isNumber }), let value = Int(digits) else { return nil }

        if digits.count <= 2 { return 2000 + value }
        if digits.count == 4 { return value }

        return nil

    }

    // Split a stored `course` into its course number and release year.
    //
    // `omittingEmptySubsequences: false` matters: a course of "_r26" (a year with no course number)
    // has an empty leading component, and Swift's default `split` would drop it and leave "r26"
    // looking like the course number.
    static func parse(course: String) -> (number: String, year: Int?) {

        let parts = course.split(separator: "_", omittingEmptySubsequences: false)

        guard parts.count >= 2, let year = year(fromSuffix: String(parts.last!)), isYearSegment(String(parts.last!)) else {
            return (course, nil)
        }

        return (parts.dropLast().joined(separator: "_"), year)

    }

    // Only a trailing "r" + digits is a year; "485_final" is just part of the course number.
    private static func isYearSegment(_ segment: String) -> Bool {
        guard segment.hasPrefix("r") || segment.hasPrefix("R") else { return false }
        let digits = segment.dropFirst()
        return !digits.isEmpty && digits.allSatisfy { $0.isNumber }
    }

    // Rebuild the stored `course`. "000" is the long-standing stand-in for a missing course number,
    // but only once a year is present — without a year an empty course must stay empty, because the
    // Properties splash lookup treats an empty course as "use the default splash image".
    static func compose(number: String, year: Int?) -> String {

        guard let year = year else { return number }

        let courseNumber = number.isEmpty ? "000" : number

        return courseNumber + "_r" + suffix(for: year)

    }

}
