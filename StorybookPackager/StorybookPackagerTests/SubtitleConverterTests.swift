//
//  SubtitleConverterTests.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  The Storybook+ player hands these bytes straight to a <track> element, which is unforgiving: one
//  comma in a timestamp or a stray cue number and the whole caption file is ignored. These tests pin
//  down the exact output for the SubRip shapes that show up in real caption exports.
//

import XCTest

class SubtitleConverterTests: XCTestCase {

    // MARK: - basic conversion

    func testConvertsSubRipToWebVTT() throws {

        let srt = """
        1
        00:00:01,000 --> 00:00:03,500
        Welcome to the course.

        2
        00:00:04,000 --> 00:00:06,000
        Let's get started.
        """

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertEqual(vtt, """
        WEBVTT

        00:00:01.000 --> 00:00:03.500
        Welcome to the course.

        00:00:04.000 --> 00:00:06.000
        Let's get started.

        """)

    }

    func testKeepsMultiLineCuePayload() throws {

        let srt = """
        1
        00:00:01,000 --> 00:00:03,000
        First line
        Second line
        """

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertTrue(vtt.hasSuffix("First line\nSecond line\n"), vtt)

    }

    func testHandlesWindowsLineEndingsAndByteOrderMark() throws {

        let srt = "\u{FEFF}1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n"

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertTrue(vtt.hasPrefix("WEBVTT\n"))
        XCTAssertFalse(vtt.contains("\r"))

    }

    func testRunTogetherCuesKeepTheirNumbersOutOfTheCaptionText() throws {

        // Cues run together *and* numbered: the number belongs to the cue below it, not to the text
        // above it, so it must not end up on screen as a stray digit.
        let srt = """
        1
        00:00:01,000 --> 00:00:02,000
        One
        2
        00:00:03,000 --> 00:00:04,000
        Two
        """

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertEqual(vtt, """
        WEBVTT

        00:00:01.000 --> 00:00:02.000
        One

        00:00:03.000 --> 00:00:04.000
        Two

        """)

    }

    func testNumberThatIsActuallyCaptionTextIsKept() throws {

        // Same shape, but the digits are followed by more text rather than a timing line — that is
        // the caption, not a cue number.
        let srt = """
        1
        00:00:01,000 --> 00:00:02,000
        42
        is the answer
        """

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertTrue(vtt.hasSuffix("42\nis the answer\n"), vtt)

    }

    func testBlankLineAfterTheTimestampDoesNotSwallowTheCue() throws {

        let srt = """
        1
        00:00:01,000 --> 00:00:02,000

        Real text
        """

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertEqual(vtt, """
        WEBVTT

        00:00:01.000 --> 00:00:02.000
        Real text

        """)

    }

    func testRunTogetherCuesStillSplit() throws {

        // Some exporters omit the blank line between cues; a timing line has to open a new cue anyway.
        let srt = """
        00:00:01,000 --> 00:00:02,000
        One
        00:00:02,000 --> 00:00:03,000
        Two
        """

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertEqual(vtt, """
        WEBVTT

        00:00:01.000 --> 00:00:02.000
        One

        00:00:02.000 --> 00:00:03.000
        Two

        """)

    }

    // MARK: - timestamps

    func testPadsShortTimestampFields() throws {

        let srt = "1\n0:1:2,5 --> 0:1:3,25\nHi"

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        // A short fraction is a decimal fraction of a second, so ",5" is half a second.
        XCTAssertTrue(vtt.contains("00:01:02.500 --> 00:01:03.250"), vtt)

    }

    func testAcceptsTimestampsWithoutHours() throws {

        let srt = "1\n01:02,000 --> 01:04,000\nHi"

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertTrue(vtt.contains("00:01:02.000 --> 00:01:04.000"), vtt)

    }

    func testDropsSubRipCoordinatesButKeepsVTTCueSettings() throws {

        let coordinates = "1\n00:00:01,000 --> 00:00:02,000 X1:040 X2:600 Y1:050 Y2:100\nHi"
        XCTAssertTrue(try SubtitleConverter.webVTT(fromSubtitleText: coordinates).contains("00:00:01.000 --> 00:00:02.000\nHi"))

        let settings = "1\n00:00:01,000 --> 00:00:02,000 align:start position:10%\nHi"
        XCTAssertTrue(try SubtitleConverter.webVTT(fromSubtitleText: settings).contains("00:00:02.000 align:start position:10%"))

    }

    func testCueSettingKeysAreLowercasedSoThePlayerAppliesThem() throws {

        let srt = "1\n00:00:01,000 --> 00:00:02,000 ALIGN:Start\nHi"

        XCTAssertTrue(try SubtitleConverter.webVTT(fromSubtitleText: srt).contains("00:00:02.000 align:Start"))

    }

    // MARK: - payload cleanup

    func testStripsMarkupTheVTTParserDoesNotUnderstand() throws {

        let srt = """
        1
        00:00:01,000 --> 00:00:02,000
        {\\an8}<font color="#ffffff">Up <i>here</i></font>
        """

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertTrue(vtt.hasSuffix("Up <i>here</i>\n"), vtt)

    }

    func testEscapesMarkupCharactersButLeavesEntitiesAndCueTags() throws {

        let srt = """
        1
        00:00:01,000 --> 00:00:02,000
        Tom & Jerry <3 &amp; 2 < 3 <b>bold</b>
        """

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertTrue(vtt.hasSuffix("Tom &amp; Jerry &lt;3 &amp; 2 &lt; 3 <b>bold</b>\n"), vtt)

    }

    func testDropsCuesWithNoRemainingText() throws {

        let srt = """
        1
        00:00:01,000 --> 00:00:02,000
        {\\an8}

        2
        00:00:03,000 --> 00:00:04,000
        Real text
        """

        let vtt = try SubtitleConverter.webVTT(fromSubtitleText: srt)

        XCTAssertEqual(vtt, """
        WEBVTT

        00:00:03.000 --> 00:00:04.000
        Real text

        """)

    }

    // MARK: - WebVTT passthrough

    func testWebVTTFilePassesThroughUntouched() throws {

        let existing = """
        WEBVTT

        NOTE recorded 2026

        intro
        00:00:01.000 --> 00:00:02.000 align:middle
        Hello

        """

        XCTAssertEqual(try SubtitleConverter.webVTT(fromSubtitleText: existing), existing)

    }

    func testHeaderPastedOnTopOfSubRipIsConvertedNotTrusted() throws {

        // The signature alone makes the track load; a browser then skips every cue whose timing it
        // cannot parse, so passing this through verbatim would leave an empty track and no error.
        let mislabelled = """
        WEBVTT

        1
        00:00:01,000 --> 00:00:02,000
        Hello
        """

        XCTAssertEqual(try SubtitleConverter.webVTT(fromSubtitleText: mislabelled), """
        WEBVTT

        00:00:01.000 --> 00:00:02.000
        Hello

        """)

    }

    func testTextThatMerelyStartsWithTheSignatureWordIsNotTakenForWebVTT() throws {

        // "WEBVTTribute" is not the signature — the seventh character has to end the word.
        let notASignature = "WEBVTTribute\n\n00:00:01,000 --> 00:00:02,000\nHello"

        XCTAssertTrue(try SubtitleConverter.webVTT(fromSubtitleText: notASignature).hasPrefix("WEBVTT\n\n00:00:01.000"))

    }

    func testWebVTTFileMissingItsHeaderIsRepaired() throws {

        // A .vtt without the signature is rejected by every player; running it through the SubRip
        // path adds the header and normalizes whatever else is off.
        let broken = "00:00:01.000 --> 00:00:02.000\nHello"

        XCTAssertEqual(try SubtitleConverter.webVTT(fromSubtitleText: broken), "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n")

    }

    // MARK: - failure

    func testFileWithNoCuesThrows() {

        XCTAssertThrowsError(try SubtitleConverter.webVTT(fromSubtitleText: "not a caption file at all")) { error in
            XCTAssertEqual(error as? SubtitleConverter.ConversionError, .noCues)
        }

    }

    // MARK: - decoding

    func testDecodesTheEncodingsCaptionToolsEmit() {

        XCTAssertEqual(SubtitleConverter.decodeText(Data("Café".utf8)), "Café")

        let utf16 = "Café".data(using: .utf16)!
        XCTAssertEqual(SubtitleConverter.decodeText(utf16), "Café")

        // 0xE9 is é in Windows-1252 / Latin-1 and invalid UTF-8 — the fallback keeps the accent
        // rather than failing the import.
        XCTAssertEqual(SubtitleConverter.decodeText(Data([0x43, 0x61, 0x66, 0xE9])), "Café")

    }

}
