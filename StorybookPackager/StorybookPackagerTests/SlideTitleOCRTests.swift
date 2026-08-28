//
//  SlideTitleOCRTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  Exercises the pure title-picking heuristic with synthetic recognized lines. Boxes use Vision's
//  normalized coordinate space: bottom-left origin, so a larger y is higher on the slide.
//

import XCTest

class SlideTitleOCRTests: XCTestCase {

    private func line(_ text: String, confidence: Float = 1.0, x: CGFloat = 0.1, y: CGFloat,
                      width: CGFloat = 0.5, height: CGFloat = 0.06,
                      angle: CGFloat = 0) -> SlideTitleOCR.TextLine {
        return SlideTitleOCR.TextLine(text: text, confidence: confidence,
                                      box: CGRect(x: x, y: y, width: width, height: height),
                                      angle: angle)
    }

    /// A label set up the side of a diagram: turned a quarter turn, and so tall and narrow that its
    /// box reaches higher up the slide than the title's and stands taller than any line on it.
    private func verticalLine(_ text: String, x: CGFloat = 0.05, y: CGFloat = 0.2,
                              height: CGFloat = 0.6) -> SlideTitleOCR.TextLine {
        return line(text, x: x, y: y, width: 0.05, height: height, angle: 90)
    }

    func testPicksTopmostLine() {
        let lines = [
            line("Body copy under the title", y: 0.5),
            line("Slide Title", y: 0.85),
            line("Footer", y: 0.05),
        ]
        XCTAssertEqual(SlideTitleOCR.titleCandidate(from: lines), "Slide Title")
    }

    func testJoinsBoxesOnTheSameVisualLine() {
        // Vision split one visual title line into two boxes at slightly different baselines;
        // they should be joined left to right.
        let lines = [
            line("Photosynthesis", x: 0.4, y: 0.85, width: 0.3),
            line("Intro to", x: 0.05, y: 0.855, width: 0.3),
            line("Body copy", y: 0.4),
        ]
        XCTAssertEqual(SlideTitleOCR.titleCandidate(from: lines), "Intro to Photosynthesis")
    }

    func testDropsLowConfidenceLines() {
        let lines = [
            line("garbled artifact", confidence: 0.2, y: 0.9),
            line("Actual Title", y: 0.8),
        ]
        XCTAssertEqual(SlideTitleOCR.titleCandidate(from: lines), "Actual Title")
    }

    func testDropsTinyTextAboveTheTitle() {
        // A footnote-sized header (course code, running head) sits above the real title but is
        // far shorter than the tallest text, so it should lose on size.
        let lines = [
            line("COURSE 101 — Week 3", y: 0.95, height: 0.015),
            line("Actual Title", y: 0.8, height: 0.06),
        ]
        XCTAssertEqual(SlideTitleOCR.titleCandidate(from: lines), "Actual Title")
    }

    func testReturnsNilWhenNothingSurvives() {
        XCTAssertNil(SlideTitleOCR.titleCandidate(from: []))
        XCTAssertNil(SlideTitleOCR.titleCandidate(from: [line("   ", y: 0.5)]))
        XCTAssertNil(SlideTitleOCR.titleCandidate(from: [line("noise", confidence: 0.1, y: 0.5)]))
    }

    // MARK: - text that isn't level

    func testALabelTurnedOnItsSideIsNotTheTitle() {

        let lines = [
            verticalLine("Rate of reaction"),
            line("Enzyme Activity", y: 0.85),
            line("Body copy", y: 0.5),
        ]

        XCTAssertEqual(SlideTitleOCR.titleCandidate(from: lines), "Enzyme Activity")

    }

    func testAVerticalLabelDoesNotSetTheSizeFloorForEverythingElse() {

        // The knock-on the tilt filter exists for: measured before it was dropped, the vertical
        // label was the tallest line on the slide, and 40% of its height put the floor above the
        // title — leaving nothing to pick at all.
        let lines = [
            verticalLine("Rate of reaction", height: 0.7),
            line("Enzyme Activity", y: 0.85, height: 0.06),
        ]

        XCTAssertEqual(SlideTitleOCR.titleCandidate(from: lines), "Enzyme Activity")

    }

    func testATitleFittedSlightlyOffLevelIsStillATitle() {

        let lines = [line("Enzyme Activity", y: 0.85, angle: 4)]

        XCTAssertEqual(SlideTitleOCR.titleCandidate(from: lines), "Enzyme Activity")

    }

    func testUpsideDownTextIsNotATitle() {

        let lines = [line("pəuɹnʇ", y: 0.9, angle: 180), line("Enzyme Activity", y: 0.85)]

        XCTAssertEqual(SlideTitleOCR.titleCandidate(from: lines), "Enzyme Activity")

    }

    func testASlideOfNothingButVerticalLabelsYieldsNoTitle() {

        XCTAssertNil(SlideTitleOCR.titleCandidate(from: [verticalLine("Rate of reaction")]))

    }

    // MARK: - which titles a guess may replace

    func testAPlaceholderTitleIsOpenToAGuess() {

        XCTAssertTrue(SlideTitleOCR.isPlaceholderTitle(""))
        XCTAssertTrue(SlideTitleOCR.isPlaceholderTitle("   "))
        XCTAssertTrue(SlideTitleOCR.isPlaceholderTitle("[Untitled]"))
        XCTAssertTrue(SlideTitleOCR.isPlaceholderTitle("[Slide 05]"))
        XCTAssertTrue(SlideTitleOCR.isPlaceholderTitle("  [Untitled]  "))

    }

    func testATitleSomebodyTypedIsLeftAlone() {

        XCTAssertFalse(SlideTitleOCR.isPlaceholderTitle("Enzyme Activity"))
        XCTAssertFalse(SlideTitleOCR.isPlaceholderTitle("Measuring Fermentation - ID Bacteria"))
        XCTAssertFalse(SlideTitleOCR.isPlaceholderTitle("[Draft] Enzyme Activity"))

    }

}
