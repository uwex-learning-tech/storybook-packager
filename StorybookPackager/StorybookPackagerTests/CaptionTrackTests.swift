//
//  CaptionTrackTests.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  The editor draws captions itself, so the cue times it reads out of a WebVTT file are the whole
//  feature: a track parsed a second off is worse than no track, because it says the captions are
//  out of sync when they aren't.
//

import XCTest

class CaptionTrackTests: XCTestCase {

    private let sample = """
    WEBVTT

    1
    00:00:01.000 --> 00:00:03.500
    The first thing said.

    2
    00:00:03.500 --> 00:00:06.000 line:90%
    The second thing,
    over two lines.
    """

    func testReadsCuesWithTheirTimes() {

        guard let track = CaptionTrack(webVTT: sample) else { return XCTFail("the sample holds two cues") }

        XCTAssertEqual(track.cues.count, 2)
        XCTAssertEqual(track.cues[0].start, 1.0, accuracy: 0.001)
        XCTAssertEqual(track.cues[0].end, 3.5, accuracy: 0.001)
        XCTAssertEqual(track.cues[0].text, "The first thing said.")

        // A cue's payload can run to several lines, and the break is part of what was written.
        XCTAssertEqual(track.cues[1].text, "The second thing,\nover two lines.")

    }

    func testFindsTheCueCoveringAMoment() {

        let track = CaptionTrack(webVTT: sample)!

        XCTAssertNil(track.text(at: 0.5), "before the first cue there is nothing to show")
        XCTAssertEqual(track.text(at: 1.0), "The first thing said.", "a cue starts at its start time")
        XCTAssertEqual(track.text(at: 3.4), "The first thing said.")

        // Adjacent cues meet at an instant; it belongs to the one starting there, not to both.
        XCTAssertEqual(track.text(at: 3.5), "The second thing,\nover two lines.")

        XCTAssertNil(track.text(at: 6.0), "a cue ends at its end time")
        XCTAssertNil(track.text(at: 99), "past the last cue there is nothing to show")

    }

    func testCueSettingsAfterTheEndTimeAreNotReadAsTime() {

        let track = CaptionTrack(webVTT: sample)!

        XCTAssertEqual(track.cues[1].end, 6.0, accuracy: 0.001)

    }

    func testAcceptsTimestampsWithoutHours() {

        let track = CaptionTrack(webVTT: "WEBVTT\n\n01:02.000 --> 01:04.000\nShort form.")

        XCTAssertEqual(track?.cues.first?.start, 62.0)
        XCTAssertEqual(track?.cues.first?.end, 64.0)

    }

    func testShowsCaptionsAsWrittenRatherThanAsMarkedUp() {

        let track = CaptionTrack(webVTT: """
        WEBVTT

        00:00:00.000 --> 00:00:02.000
        <v Narrator><i>Tom &amp; Jerry</i> &lt;the cartoon&gt;
        """)

        XCTAssertEqual(track?.cues.first?.text, "Tom & Jerry <the cartoon>")

    }

    func testAFileWithNoCuesIsNoTrackAtAll() {

        // Nothing to draw, and an empty caption bar over a slide is worse than none.
        XCTAssertNil(CaptionTrack(webVTT: "WEBVTT\n\n"))
        XCTAssertNil(CaptionTrack(webVTT: ""))
        XCTAssertNil(CaptionTrack(webVTT: "WEBVTT\n\nNOTE this file is all notes and no cues\n"))

        // A cue whose payload is empty, or whose timing runs backwards, is not a cue.
        XCTAssertNil(CaptionTrack(webVTT: "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n\n"))
        XCTAssertNil(CaptionTrack(webVTT: "WEBVTT\n\n00:00:02.000 --> 00:00:01.000\nBackwards.\n"))

    }

    func testCuesOutOfOrderInTheFileAreStillFoundByTime() {

        let track = CaptionTrack(webVTT: """
        WEBVTT

        00:00:10.000 --> 00:00:12.000
        Later.

        00:00:01.000 --> 00:00:02.000
        Earlier.
        """)

        XCTAssertEqual(track?.text(at: 1.5), "Earlier.")
        XCTAssertEqual(track?.text(at: 11), "Later.")

    }

    func testWindowsLineEndingsAndAByteOrderMarkDoNotHideTheCues() {

        let track = CaptionTrack(webVTT: "\u{FEFF}WEBVTT\r\n\r\n00:00:01.000 --> 00:00:02.000\r\nStill read.\r\n")

        XCTAssertEqual(track?.cues.count, 1)
        XCTAssertEqual(track?.cues.first?.text, "Still read.")

    }

    // MARK: - which slides carry captions

    func testOnlySlidesWhoseMediaThePresentationHoldsCanBeCaptioned() {

        XCTAssertEqual(CaptionTrack.assetDirectory(forPageType: PageTypes.IMAGE_AUDIO), FileNames.AUDIO_DIR)
        XCTAssertEqual(CaptionTrack.assetDirectory(forPageType: PageTypes.BUNDLE), FileNames.AUDIO_DIR)
        XCTAssertEqual(CaptionTrack.assetDirectory(forPageType: PageTypes.VIDEO), FileNames.VIDEO_DIR)

        // A hosted video's captions come from its host; the rest have no media to caption.
        for type in [PageTypes.KALTURA, PageTypes.YOUTUBE, PageTypes.VIMEO, PageTypes.IMAGE, PageTypes.QUIZ, PageTypes.HTML, PageTypes.SECTION] {
            XCTAssertNil(CaptionTrack.assetDirectory(forPageType: type), "type: \(type)")
            XCTAssertFalse(CaptionTrack.supportsCaptions(pageType: type), "type: \(type)")
        }

    }

    func testCaptionsAreNamedForTheSlideNotForAFrameWithinIt() {

        XCTAssertEqual(CaptionTrack.fileName(forPageSource: "sb03"), "sb03.vtt")

    }

    // MARK: - the outline's mark

    func testTheMarkSaysWhichOfTheThreeStatesASlideIsIn() {

        XCTAssertEqual(CaptionBadge.state(pageType: PageTypes.VIDEO, hasCaptions: true), .captioned)
        XCTAssertEqual(CaptionBadge.state(pageType: PageTypes.VIDEO, hasCaptions: false), .missing)

        // A slide that cannot take captions is not merely missing them.
        XCTAssertEqual(CaptionBadge.state(pageType: PageTypes.YOUTUBE, hasCaptions: false), .unsupported)
        XCTAssertEqual(CaptionBadge.state(pageType: PageTypes.YOUTUBE, hasCaptions: true), .unsupported)

    }

    func testEveryRowIsMarkedSoAGapAlwaysMeansSomething() {

        let captioned = CaptionBadge.typeLabel("VIDEO", state: .captioned, baseFont: nil).string
        let missing = CaptionBadge.typeLabel("VIDEO", state: .missing, baseFont: nil).string
        let unsupported = CaptionBadge.typeLabel("YOUTUBE", state: .unsupported, baseFont: nil).string

        XCTAssertTrue(captioned.hasSuffix("CC"))
        XCTAssertTrue(missing.hasSuffix("CC"))
        XCTAssertFalse(unsupported.contains("CC"))
        XCTAssertTrue(unsupported.hasPrefix("YOUTUBE"))
        XCTAssertGreaterThan(unsupported.count, "YOUTUBE".count, "an unsupported slide still carries a placeholder")

    }

    func testTheMarkIsDimmedRatherThanHiddenWhenCaptionsAreMissing() {

        func colour(_ state: CaptionBadge.State) -> NSColor? {
            let label = CaptionBadge.typeLabel("VIDEO", state: state, baseFont: nil)
            return label.attribute(.foregroundColor, at: label.length - 1, effectiveRange: nil) as? NSColor
        }

        XCTAssertEqual(colour(.captioned), .labelColor)
        XCTAssertEqual(colour(.missing), .tertiaryLabelColor)
        XCTAssertEqual(colour(.unsupported), .quaternaryLabelColor)

    }

}
