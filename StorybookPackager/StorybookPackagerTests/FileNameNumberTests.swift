//
//  FileNameNumberTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  Every imported asset is keyed by the page number its file name ends in, so this parse runs on
//  each file the user drops — including whatever they happened to name it.
//

import XCTest

class FileNameNumberTests: XCTestCase {

    func testReadsThePageNumberOffTheEndOfTheName() {

        XCTAssertEqual(Util.shared.parseNumFromFileName(string: "lecture03"), "03")
        XCTAssertEqual(Util.shared.parseNumFromFileName(string: "lecture12"), "12")

    }

    func testSingleDigitGetsALeadingZero() {

        XCTAssertEqual(Util.shared.parseNumFromFileName(string: "lecture3"), "03")

    }

    func testKeepsTheFrameSuffixOfABundleImage() {

        XCTAssertEqual(Util.shared.parseNumFromFileName(string: "lecture03-2"), "03-2")
        XCTAssertEqual(Util.shared.parseNumFromFileName(string: "lecture3-2"), "03-2")

    }

    func testNameWithoutDigitsReturnsNothingInsteadOfCrashing() {

        // Reading the number out of an empty match used to trap on an empty array and take the app
        // down with it — one drop of a file named "captions.srt" was enough.
        XCTAssertEqual(Util.shared.parseNumFromFileName(string: "captions"), "")
        XCTAssertEqual(Util.shared.parseNumFromFileName(string: ""), "")
        XCTAssertEqual(Util.shared.parseNumFromFileName(string: "-"), "")

    }

}
