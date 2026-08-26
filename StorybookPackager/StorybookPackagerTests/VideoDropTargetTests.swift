//
//  VideoDropTargetTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  Dropping a video onto a slide replaces what is there without asking, so the two rules that
//  decide when it may happen at all — what counts as a video drop, and when the captions already on
//  the slide are stale — are the whole of the safety net.
//

import XCTest

class VideoDropTargetTests: XCTestCase {

    // MARK: - what the preview accepts

    func testTakesASingleMp4WhateverItIsCalled() {

        let url = URL(fileURLWithPath: "/somewhere/lecture take 3.mp4")

        XCTAssertEqual(VideoDropTarget.videoURL(from: [url]), url)

    }

    func testTakesAnMp4SpelledInCapitals() {

        let url = URL(fileURLWithPath: "/somewhere/CLIP.MP4")

        XCTAssertEqual(VideoDropTarget.videoURL(from: [url]), url)

    }

    func testRefusesMoreThanOneFile() {

        let urls = [URL(fileURLWithPath: "/a/one.mp4"), URL(fileURLWithPath: "/a/two.mp4")]

        XCTAssertNil(VideoDropTarget.videoURL(from: urls))

    }

    func testRefusesAnythingThatIsNotAnMp4() {

        XCTAssertNil(VideoDropTarget.videoURL(from: [URL(fileURLWithPath: "/a/slide.jpg")]))
        XCTAssertNil(VideoDropTarget.videoURL(from: [URL(fileURLWithPath: "/a/narration.mp3")]))
        XCTAssertNil(VideoDropTarget.videoURL(from: []))

    }

    func testOnlyVideoSlidesTakeADrop() {

        XCTAssertTrue(VideoDropTarget.accepts(pageType: PageTypes.VIDEO))
        XCTAssertTrue(VideoDropTarget.accepts(pageType: PageTypes.KALTURA))
        XCTAssertTrue(VideoDropTarget.accepts(pageType: PageTypes.YOUTUBE))
        XCTAssertTrue(VideoDropTarget.accepts(pageType: PageTypes.VIMEO))

        XCTAssertFalse(VideoDropTarget.accepts(pageType: PageTypes.IMAGE))
        XCTAssertFalse(VideoDropTarget.accepts(pageType: PageTypes.IMAGE_AUDIO))
        XCTAssertFalse(VideoDropTarget.accepts(pageType: PageTypes.BUNDLE))
        XCTAssertFalse(VideoDropTarget.accepts(pageType: PageTypes.SECTION))

    }

    // MARK: - whether the captions still describe the video

    func testCaptionsEndingWithTheVideoFit() {
        XCTAssertTrue(VideoDropTarget.captionsFit(lastCueEnd: 598, videoDuration: 600))
    }

    func testCaptionsOverATrailingSilenceStillFit() {
        // Half a minute of nobody speaking at the end of a ten-minute video is ordinary.
        XCTAssertTrue(VideoDropTarget.captionsFit(lastCueEnd: 570, videoDuration: 600))
    }

    func testCaptionsRunningPastTheEndDoNotFit() {
        XCTAssertFalse(VideoDropTarget.captionsFit(lastCueEnd: 610, videoDuration: 600))
    }

    func testCaptionsStoppingLongBeforeTheEndDoNotFit() {
        XCTAssertFalse(VideoDropTarget.captionsFit(lastCueEnd: 120, videoDuration: 600))
    }

    func testShortVideosGetAFewSecondsOfLeeway() {

        XCTAssertTrue(VideoDropTarget.captionsFit(lastCueEnd: 8, videoDuration: 10))
        XCTAssertFalse(VideoDropTarget.captionsFit(lastCueEnd: 4, videoDuration: 10))

    }

    func testADurationThatCouldNotBeReadRaisesNoWarning() {

        XCTAssertTrue(VideoDropTarget.captionsFit(lastCueEnd: 300, videoDuration: 0))
        XCTAssertTrue(VideoDropTarget.captionsFit(lastCueEnd: 300, videoDuration: .nan))
        XCTAssertTrue(VideoDropTarget.captionsFit(lastCueEnd: 300, videoDuration: .infinity))

    }

}
