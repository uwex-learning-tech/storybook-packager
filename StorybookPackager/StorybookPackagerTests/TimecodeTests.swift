//
//  TimecodeTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  A frame's timecode is written one way and shown another: stored compact, so the player and every
//  existing presentation still read it, and shown in full, so a column of them can be read straight
//  down. The two have to agree about the moment they describe.
//

import XCTest

class TimecodeTests: XCTestCase {

    private let util = Util.shared

    // MARK: - the display form

    func testAWholeSecondStillShowsItsHundredths() {
        XCTAssertEqual(util.fullTimeAsString(timeInterval: 4), "00:04.00")
    }

    func testHundredthsAreKept() {
        XCTAssertEqual(util.fullTimeAsString(timeInterval: 77.5), "01:17.50")
    }

    /// Frames have no hours field, so the minutes carry on past 60 rather than wrapping — which is
    /// what used to put a frame an hour in above the one before it.
    func testPastAnHourTheMinutesKeepCounting() {
        XCTAssertEqual(util.fullTimeAsString(timeInterval: 3700), "61:40.00")
        XCTAssertEqual(util.fullTimeAsString(timeInterval: 3600), "60:00.00")
    }

    func testZeroIsFullyPadded() {
        XCTAssertEqual(util.fullTimeAsString(timeInterval: 0), "00:00.00")
    }

    func testEveryDisplayedTimecodeIsTheSameWidth() {

        // Anything a slide's narration plausibly runs to, up to an hour past the longest we have.
        let widths = Set([0.0, 4.0, 77.5, 599.0, 3599.99, 3700.0].map {
            util.fullTimeAsString(timeInterval: $0).count
        })

        XCTAssertEqual(widths, [8], "a ragged column is the whole reason this form exists")

    }

    /// Without an hours field the minutes eventually need a third digit, which happens at 100
    /// minutes — an hour and forty on one slide's narration. Everything shorter shares a width.
    func testTheMinutesFieldGrowsAtAHundredMinutes() {

        XCTAssertEqual(util.fullTimeAsString(timeInterval: 5_999), "99:59.00")
        XCTAssertEqual(util.fullTimeAsString(timeInterval: 6_000), "100:00.00")

    }

    // MARK: - reading a stored timecode back

    func testShowsStoredCompactFormsInFull() {

        XCTAssertEqual(util.fullTimecode(from: "00:00"), "00:00.00")
        XCTAssertEqual(util.fullTimecode(from: "05:47"), "05:47.00")
        XCTAssertEqual(util.fullTimecode(from: "00:04.75"), "00:04.75")
        // Still read back correctly if a presentation already has one stored with an hours field.
        XCTAssertEqual(util.fullTimecode(from: "01:01:40"), "61:40.00")

    }

    /// The display form has to be readable back, because the cell showing it is editable: what is
    /// typed there is what gets stored.
    func testTheDisplayedFormReadsBackAsTheSameMoment() {

        for stored in ["00:00", "05:47", "00:04.75", "01:01:40", "59:59.99"] {

            let shown = util.fullTimecode(from: stored)

            XCTAssertEqual(util.timeStringToSeconds(time: shown),
                           util.timeStringToSeconds(time: stored),
                           accuracy: 0.005,
                           "\(stored) shown as \(shown)")

        }

    }

    func testStoringWhatIsDisplayedLeavesTheCompactFormUnchanged() {

        // sanitizeTime is what the editor runs an edited cell through before storing it.
        XCTAssertEqual(util.sanitizeTime(timecode: "00:00:04.00"), "00:04")
        XCTAssertEqual(util.sanitizeTime(timecode: "00:05:47.00"), "05:47")
        XCTAssertEqual(util.sanitizeTime(timecode: "00:00:04.75"), "00:04.75")
        XCTAssertEqual(util.sanitizeTime(timecode: "01:01:40.00"), "01:01:40")

    }

}
