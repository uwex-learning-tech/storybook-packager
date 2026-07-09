//
//  ReleaseYearTests.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  The `course` attribute is read by the Storybook+ player, so these tests pin down the exact bytes
//  ReleaseYear.compose() emits and the round trip through ReleaseYear.parse().
//

import XCTest

class ReleaseYearTests: XCTestCase {

    // MARK: - suffix

    func testSuffixIsTheLastTwoDigits() {
        XCTAssertEqual(ReleaseYear.suffix(for: 2026), "26")
        XCTAssertEqual(ReleaseYear.suffix(for: 2017), "17")
        XCTAssertEqual(ReleaseYear.suffix(for: 2037), "37")
    }

    // MARK: - year(fromSuffix:)

    func testYearFromSuffix() {
        XCTAssertEqual(ReleaseYear.year(fromSuffix: "26"), 2026)
        XCTAssertEqual(ReleaseYear.year(fromSuffix: "r26"), 2026)
        XCTAssertEqual(ReleaseYear.year(fromSuffix: "2026"), 2026)
        XCTAssertEqual(ReleaseYear.year(fromSuffix: "r17"), 2017)
        XCTAssertEqual(ReleaseYear.year(fromSuffix: "r37"), 2037)
    }

    func testYearFromSuffixRejectsNonNumeric() {
        XCTAssertNil(ReleaseYear.year(fromSuffix: ""))
        XCTAssertNil(ReleaseYear.year(fromSuffix: "r"))
        XCTAssertNil(ReleaseYear.year(fromSuffix: "final"))
        XCTAssertNil(ReleaseYear.year(fromSuffix: "r2x"))
    }

    // MARK: - parse

    func testParseSplitsCourseAndYear() {

        let full = ReleaseYear.parse(course: "apc472_r26")
        XCTAssertEqual(full.number, "apc472")
        XCTAssertEqual(full.year, 2026)

        let numeric = ReleaseYear.parse(course: "485_r26")
        XCTAssertEqual(numeric.number, "485")
        XCTAssertEqual(numeric.year, 2026)

        let placeholder = ReleaseYear.parse(course: "000_r26")
        XCTAssertEqual(placeholder.number, "000")
        XCTAssertEqual(placeholder.year, 2026)

    }

    // The bug this replaced: Swift's `split` drops empty subsequences, so "_r26" yielded a single
    // element and "r26" was painted into the Course Number field.
    func testParseYearOnlyCourseKeepsAnEmptyNumber() {

        let yearOnly = ReleaseYear.parse(course: "_r26")
        XCTAssertEqual(yearOnly.number, "")
        XCTAssertEqual(yearOnly.year, 2026)

    }

    func testParseCourseWithNoYear() {

        let bare = ReleaseYear.parse(course: "485")
        XCTAssertEqual(bare.number, "485")
        XCTAssertNil(bare.year)

        let empty = ReleaseYear.parse(course: "")
        XCTAssertEqual(empty.number, "")
        XCTAssertNil(empty.year)

    }

    func testParseDoesNotMistakeANonYearSegmentForAYear() {

        let suffixed = ReleaseYear.parse(course: "485_final")
        XCTAssertEqual(suffixed.number, "485_final")
        XCTAssertNil(suffixed.year)

    }

    // MARK: - compose

    func testComposeMatchesTheStoredFormat() {
        XCTAssertEqual(ReleaseYear.compose(number: "apc472", year: 2026), "apc472_r26")
        XCTAssertEqual(ReleaseYear.compose(number: "485", year: 2017), "485_r17")
        XCTAssertEqual(ReleaseYear.compose(number: "485", year: 2037), "485_r37")
    }

    func testComposeSubstitutesThePlaceholderNumberOnlyWhenAYearIsPresent() {
        XCTAssertEqual(ReleaseYear.compose(number: "", year: 2026), "000_r26")
        XCTAssertEqual(ReleaseYear.compose(number: "", year: nil), "")
    }

    func testComposeOmitsTheSuffixWithoutAYear() {
        XCTAssertEqual(ReleaseYear.compose(number: "485", year: nil), "485")
    }

    // MARK: - round trip

    func testRoundTripIsLosslessForWellFormedCourses() {

        for course in ["apc472_r26", "485_r26", "000_r26", "485", "485_final", ""] {
            let parsed = ReleaseYear.parse(course: course)
            XCTAssertEqual(ReleaseYear.compose(number: parsed.number, year: parsed.year), course)
        }

    }

    // A course that is nothing but a year normalizes to the "000" placeholder number on the way back
    // out — the state the Properties dialog's ordering bug used to produce.
    func testRoundTripNormalizesAYearOnlyCourse() {

        let parsed = ReleaseYear.parse(course: "_r26")
        XCTAssertEqual(ReleaseYear.compose(number: parsed.number, year: parsed.year), "000_r26")

    }

    // MARK: - range

    func testRangeEndpoints() {
        XCTAssertEqual(ReleaseYear.range.lowerBound, 2017)
        XCTAssertEqual(ReleaseYear.range.upperBound, 2037)
        XCTAssertEqual(ReleaseYear.titles.count, 21)
        XCTAssertEqual(ReleaseYear.titles.first, "2017")
        XCTAssertEqual(ReleaseYear.titles.last, "2037")
    }

    func testCurrentIsClampedIntoTheOfferedRange() {
        XCTAssertTrue(ReleaseYear.range.contains(ReleaseYear.current))
    }

}
