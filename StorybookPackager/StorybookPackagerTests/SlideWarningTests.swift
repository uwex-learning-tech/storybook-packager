//
//  SlideWarningTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  The states flagged here are the ones ordinary editing produces and nothing else complains about:
//  a slide set to play narration that has none, captions left beside audio that was removed. The
//  mark is only worth having if it means something, so a slide that is merely incomplete in a way
//  the author is obviously mid-way through must not raise one.
//

import XCTest

class SlideWarningTests: XCTestCase {

    private func slide(_ type: String,
                       src: String = "sb04",
                       image: Bool = true,
                       audio: Bool = true,
                       video: Bool = true,
                       captions: Bool = false) -> SlideInventory {

        return SlideInventory(type: type, src: src, hasImage: image, hasAudio: audio, hasVideo: video, hasCaptions: captions)

    }

    // MARK: - the two states this was built for

    func testNarratedSlideWithNoAudioIsFlagged() {

        let warnings = SlideWarning.warnings(for: slide(PageTypes.IMAGE_AUDIO, audio: false))

        XCTAssertEqual(warnings, [.missingAudio])
        XCTAssertEqual(SlideWarning.tooltip(for: warnings), "This slide is set to play narration, but has no audio.")

    }

    func testCaptionsWithNothingToCaptionAreFlagged() {

        XCTAssertEqual(SlideWarning.warnings(for: slide(PageTypes.IMAGE_AUDIO, audio: false, captions: true)),
                       [.missingAudio, .captionsWithoutAudio])

        XCTAssertEqual(SlideWarning.warnings(for: slide(PageTypes.VIDEO, video: false, captions: true)),
                       [.missingVideo, .captionsWithoutVideo])

        // Captions beside the media they caption are the ordinary case and say nothing.
        XCTAssertTrue(SlideWarning.warnings(for: slide(PageTypes.VIDEO, captions: true)).isEmpty)
        XCTAssertTrue(SlideWarning.warnings(for: slide(PageTypes.IMAGE_AUDIO, captions: true)).isEmpty)

    }

    // MARK: - the rest of the family

    func testEachTypeIsJudgedByWhatItNeeds() {

        XCTAssertEqual(SlideWarning.warnings(for: slide(PageTypes.IMAGE, image: false)), [.missingImage])
        XCTAssertEqual(SlideWarning.warnings(for: slide(PageTypes.VIDEO, video: false)), [.missingVideo])
        XCTAssertEqual(SlideWarning.warnings(for: slide(PageTypes.BUNDLE, image: false)), [.missingBundleImages])

        // A hosted video is named by its ID and nothing else.
        for type in [PageTypes.KALTURA, PageTypes.YOUTUBE, PageTypes.VIMEO] {
            XCTAssertEqual(SlideWarning.warnings(for: slide(type, src: "")), [.missingVideoId], "type: \(type)")
            XCTAssertEqual(SlideWarning.warnings(for: slide(type, src: "   ")), [.missingVideoId], "type: \(type)")
            XCTAssertTrue(SlideWarning.warnings(for: slide(type, src: "0_ab12cd34")).isEmpty, "type: \(type)")
        }

    }

    func testASlideMissingSeveralThingsSaysSoOnce_perThing() {

        let warnings = SlideWarning.warnings(for: slide(PageTypes.IMAGE_AUDIO, image: false, audio: false, captions: true))

        // Media first: what is missing is the cause, the stranded captions the consequence.
        XCTAssertEqual(warnings, [.missingImage, .missingAudio, .captionsWithoutAudio])
        XCTAssertEqual(SlideWarning.tooltip(for: warnings)?.components(separatedBy: "\n").count, 3)

    }

    func testAWholeSlideRaisesNothing() {

        XCTAssertTrue(SlideWarning.warnings(for: slide(PageTypes.IMAGE)).isEmpty)
        XCTAssertTrue(SlideWarning.warnings(for: slide(PageTypes.IMAGE_AUDIO)).isEmpty)
        XCTAssertTrue(SlideWarning.warnings(for: slide(PageTypes.BUNDLE)).isEmpty)
        XCTAssertTrue(SlideWarning.warnings(for: slide(PageTypes.VIDEO)).isEmpty)

        XCTAssertNil(SlideWarning.tooltip(for: []))

    }

    func testTypesThatCarryNoMediaOfThisKindAreLeftAlone() {

        // A quiz, an HTML slide, a notes slide or a section header holds nothing that can be
        // half-set, and marking them would make the mark mean nothing.
        for type in [PageTypes.QUIZ, PageTypes.HTML, PageTypes.SECTION] {
            XCTAssertTrue(SlideWarning.warnings(for: slide(type, src: "", image: false, audio: false, video: false)).isEmpty,
                          "type: \(type)")
        }

    }

    func testTheMarkIsThereToBeSeen() {

        let mark = SlideWarning.mark(baseFont: nil)

        XCTAssertTrue(mark.string.contains("\u{26A0}"))
        XCTAssertEqual(mark.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .systemOrange)

    }

}
