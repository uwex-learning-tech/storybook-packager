//
//  ImportSkipReportTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  The end-of-import report is the only thing a person sees about a file that didn't make it, so
//  what it says has to be true of the page it says it about. A caption dropped on a YouTube slide
//  used to be told the page had no video to attach to — of a page whose whole content is a video —
//  which sends someone off to import an .mp4 that would destroy the slide if they found one.
//

import XCTest

class ImportSkipReportTests: XCTestCase {

    private typealias Reason = ImportSkipReason

    func testAStreamingSlideIsNotToldToImportAVideoItAlreadyHas() {

        let report = ImportSkipReason.report([("page38.vtt", .captionOnStreamingSlide)])

        XCTAssertTrue(report.hasPrefix("page38.vtt\n"))
        XCTAssertTrue(report.contains("Kaltura, YouTube, or Vimeo"))
        XCTAssertTrue(report.contains("add them there"))

        // The advice that fits a page with no media at all must not leak into this one.
        XCTAssertFalse(report.contains("Import the audio or video"))

    }

    func testOneFileIsWrittenAsOne() {

        for reason in [Reason.noPageNumber, .captionWithoutMedia, .captionOnStreamingSlide, .unreadableCaption] {

            let single = reason.explanation(count: 1)

            XCTAssertFalse(single.contains("These "), "reason: \(reason)")
            XCTAssertFalse(single.contains("Those "), "reason: \(reason)")

        }

    }

    func testSeveralFilesAreWrittenAsSeveral() {

        for reason in [Reason.noPageNumber, .captionWithoutMedia, .captionOnStreamingSlide, .unreadableCaption] {

            let several = reason.explanation(count: 3)

            XCTAssertFalse(several.contains("This "), "reason: \(reason)")
            XCTAssertFalse(several.contains("That "), "reason: \(reason)")
            XCTAssertNotEqual(several, reason.explanation(count: 1), "reason: \(reason)")

        }

    }

    func testFilesAreGroupedByReasonInAFixedOrder() {

        let report = ImportSkipReason.report([
            ("broken.vtt", .unreadableCaption),
            ("page38.vtt", .captionOnStreamingSlide),
            ("lecture.mp3", .noPageNumber),
            ("page12.vtt", .captionWithoutMedia),
            ("page39.vtt", .captionOnStreamingSlide)
        ])

        let paragraphs = report.components(separatedBy: "\n\n")

        XCTAssertEqual(paragraphs.count, 4)
        XCTAssertTrue(paragraphs[0].hasPrefix("lecture.mp3\n"))
        XCTAssertTrue(paragraphs[1].hasPrefix("page12.vtt\n"))
        // Files sharing a reason are listed together, on one line, in the order they were skipped.
        XCTAssertTrue(paragraphs[2].hasPrefix("page38.vtt, page39.vtt\n"))
        XCTAssertTrue(paragraphs[3].hasPrefix("broken.vtt\n"))

    }

    func testAReasonNothingWasSkippedForIsLeftOut() {

        let report = ImportSkipReason.report([("page38.vtt", .captionOnStreamingSlide)])

        XCTAssertEqual(report.components(separatedBy: "\n\n").count, 1)

    }

}
