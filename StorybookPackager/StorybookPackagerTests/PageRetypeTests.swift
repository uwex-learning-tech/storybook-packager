//
//  PageRetypeTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  Every case here is one a slide could be walked into from the type popup, silently, with the loss
//  arriving at the next save and the undo history already cleared by it.
//

import XCTest

class PageRetypeTests: XCTestCase {

    private let fmt = FileExtensions.JPG

    private func impact(_ from: String, _ to: String,
                        src: String = "page03",
                        audio: String = "",
                        frames: Int = 1,
                        holding: Set<String> = []) -> PageRetype.Impact {

        return PageRetype.impact(from: from, to: to, src: src, audio: audio, frameCount: frames, imageFormat: fmt,
                                 holdsFile: { holding.contains("\($0.subdir)/\($0.name)") })

    }

    // MARK: - within the media group

    func testDroppingAudioFromANarratedSlideNamesTheFilesItLoses() {

        let i = impact(PageTypes.IMAGE_AUDIO, PageTypes.IMAGE,
                       holding: ["pages/page03.jpg", "audio/page03.mp3", "audio/page03.vtt"])

        XCTAssertEqual(i.losesFiles, ["page03.mp3", "page03.vtt"])
        XCTAssertTrue(i.isDestructive)
        XCTAssertFalse(i.clearsSrc, "the slide is still a media slide, so its name still means what it meant")

    }

    func testAddingAudioToAnImageSlideCostsNothing() {

        let i = impact(PageTypes.IMAGE, PageTypes.IMAGE_AUDIO, holding: ["pages/page03.jpg"])

        XCTAssertEqual(i.losesFiles, [])
        XCTAssertFalse(i.isDestructive)

    }

    // An image and a bundle frame are different file names, so neither survives the other.
    func testImageToBundleLosesThePicture() {

        let i = impact(PageTypes.IMAGE, PageTypes.BUNDLE, holding: ["pages/page03.jpg"])

        XCTAssertEqual(i.losesFiles, ["page03.jpg"])

    }

    func testBundleToImageLosesEveryFrameAndClearsTheFrameList() {

        let i = impact(PageTypes.BUNDLE, PageTypes.IMAGE, frames: 3,
                       holding: ["pages/page03-1.jpg", "pages/page03-2.jpg", "pages/page03-3.jpg"])

        XCTAssertEqual(i.losesFiles, ["page03-1.jpg", "page03-2.jpg", "page03-3.jpg"])
        XCTAssertTrue(i.clearsFrames, "a frame list on a slide that is not a bundle is still written out")

    }

    func testASlideHoldingNothingLosesNothing() {

        XCTAssertFalse(impact(PageTypes.IMAGE_AUDIO, PageTypes.IMAGE).isDestructive)

    }

    // MARK: - crossing between the three meanings of src

    // The case that published "page02" to the player as a YouTube ID.
    func testMediaToStreamingClearsTheNameAndSaysWhatGoes() {

        let i = impact(PageTypes.IMAGE_AUDIO, PageTypes.YOUTUBE,
                       holding: ["pages/page03.jpg", "audio/page03.mp3"])

        XCTAssertTrue(i.clearsSrc, "a base name read as a video ID is published as one")
        XCTAssertEqual(i.losesFiles, ["page03.jpg", "page03.mp3"])

    }

    func testStreamingToMediaSaysTheVideoIdCannotComeBack() {

        let i = impact(PageTypes.YOUTUBE, PageTypes.IMAGE, src: "dQw4w9WgXcQ")

        XCTAssertTrue(i.losesVideoId)
        XCTAssertTrue(i.clearsSrc)
        XCTAssertTrue(i.isDestructive)

    }

    func testEmbeddedToMediaGivesUpTheContentAndItsNarration() {

        let i = impact(PageTypes.HTML, PageTypes.IMAGE, src: "myWidget", audio: "page04.mp3",
                       holding: ["audio/page04.mp3"])

        XCTAssertTrue(i.losesEmbeddedContent)
        XCTAssertTrue(i.clearsSrc)
        XCTAssertTrue(i.clearsAudio)
        XCTAssertEqual(i.losesFiles, ["page04.mp3"], "the narration is filed by its own reference, not under src")

    }

    func testLeavingAQuizSaysTheQuestionGoes() {

        let i = impact(PageTypes.QUIZ, PageTypes.IMAGE, src: "")

        XCTAssertTrue(i.losesQuiz)
        XCTAssertTrue(i.isDestructive)

    }

    // Switching between kinds of quiz keeps the question and its media — the one transition the app
    // already reconciled, and it must stay free.
    func testChangingQuizKindCostsNothing() {

        XCTAssertFalse(impact(PageTypes.MULTIPLE_CHOICE, PageTypes.SHORT_ANSWER, src: "").isDestructive)

    }

    func testSameTypeIsNeverAChange() {

        XCTAssertFalse(impact(PageTypes.IMAGE, PageTypes.IMAGE, holding: ["pages/page03.jpg"]).isDestructive)

    }

    // MARK: - the question put to the author

    func testConfirmationNamesTheSlideAndTheFiles() {

        let i = impact(PageTypes.IMAGE_AUDIO, PageTypes.IMAGE, holding: ["audio/page03.mp3"])

        let question = PageRetype.confirmation(i, slideNumber: 4)

        XCTAssertEqual(question?.message, "Change the type of page 4?")
        XCTAssertEqual(question?.detail.contains("page03.mp3"), true)

    }

    func testNoQuestionWhenNothingIsLost() {

        XCTAssertNil(PageRetype.confirmation(impact(PageTypes.IMAGE, PageTypes.IMAGE_AUDIO), slideNumber: 1))

    }

}
