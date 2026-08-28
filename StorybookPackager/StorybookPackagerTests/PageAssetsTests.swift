//
//  PageAssetsTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  A slide's files are built by concatenation from one base name, and that construction used to be
//  written out separately in four places. They drifted, and a slide ended up reading and overwriting
//  its neighbour's files. These tests pin the one list they all read from now — including the
//  property that made the drift possible in the first place: that the union used to reserve a name
//  really does cover every type's list.
//

import XCTest

class PageAssetsTests: XCTestCase {

    private func names(_ type: String, base: String = "page02", format: String = FileExtensions.JPG, frames: Int = 1) -> [String] {

        return PageAssets.slots(type: type, base: base, imageFormat: format, frameCount: frames).map { "\($0.subdir)/\($0.name)" }

    }

    // MARK: - what each type occupies

    func testImageSlideHoldsOnlyItsImage() {

        XCTAssertEqual(names(PageTypes.IMAGE), ["pages/page02.jpg"])

    }

    func testImageAudioSlideHoldsImageNarrationAndCaptions() {

        XCTAssertEqual(names(PageTypes.IMAGE_AUDIO),
                       ["pages/page02.jpg", "audio/page02.mp3", "audio/page02.vtt"])

    }

    func testVideoSlideHoldsItsVideoAndCaptions() {

        XCTAssertEqual(names(PageTypes.VIDEO), ["video/page02.mp4", "video/page02.vtt"])

    }

    func testBundleHoldsOneImagePerFramePlusNarration() {

        XCTAssertEqual(names(PageTypes.BUNDLE, frames: 3),
                       ["pages/page02-1.jpg", "pages/page02-2.jpg", "pages/page02-3.jpg",
                        "audio/page02.mp3", "audio/page02.vtt"])

    }

    // The name the first frame added to an empty bundle will take has to be reserved along with the
    // rest, or the bundle's own name is free for another slide to claim out from under it.
    func testEmptyBundleStillHoldsOneFrameSlot() {

        XCTAssertEqual(names(PageTypes.BUNDLE, frames: 0),
                       ["pages/page02-1.jpg", "audio/page02.mp3", "audio/page02.vtt"])

    }

    // MARK: - the types that carry no files

    func testTypesWithoutFilesOccupyNothing() {

        for type in [PageTypes.SECTION, PageTypes.QUIZ, PageTypes.HTML,
                     PageTypes.YOUTUBE, PageTypes.VIMEO, PageTypes.KALTURA,
                     PageTypes._DEL, PageTypes._MOVE] {

            XCTAssertEqual(names(type), [], "\(type) should occupy no files")
            XCTAssertFalse(PageAssets.holdsMediaFiles(type: type), "\(type) files nothing under its src")

        }

    }

    func testTypesWithFilesAreReportedAsHoldingThem() {

        for type in [PageTypes.IMAGE, PageTypes.IMAGE_AUDIO, PageTypes.BUNDLE, PageTypes.VIDEO] {
            XCTAssertTrue(PageAssets.holdsMediaFiles(type: type), "\(type) files its assets under its src")
        }

    }

    // MARK: - how the name is built

    // The presentation's format is followed as it is written, not canonicalised: every other path
    // that names a slide image reads pageImgFormat raw, so a file named ".jpg" here would be one
    // none of them look for.
    func testImageFormatIsFollowedVerbatim() {

        XCTAssertEqual(names(PageTypes.IMAGE, format: FileExtensions.JPEG), ["pages/page02.jpeg"])
        XCTAssertEqual(names(PageTypes.IMAGE, format: FileExtensions.SVG), ["pages/page02.svg"])

    }

    // Whatever base it is given, verbatim — the padding is the caller's, and a bundle seeded "page5"
    // once wrote frames the editor then looked for under "page05".
    func testBaseNameIsUsedAsGiven() {

        XCTAssertEqual(names(PageTypes.IMAGE, base: "page05"), ["pages/page05.jpg"])
        XCTAssertEqual(names(PageTypes.IMAGE, base: "page05_copy1"), ["pages/page05_copy1.jpg"])

    }

    // MARK: - the union a name is reserved against

    // A slide's type can change after it takes its name, without the name changing. Reserving only
    // against the type it happens to be right now is how an image slide came to want narration filed
    // under a name a neighbour already held.
    func testUnionCoversEverySingleTypesSlots() {

        for frames in [0, 1, 4] {

            let union = PageAssets.allMediaSlots(base: "page02", imageFormat: FileExtensions.JPG, frameCount: frames)

            for type in [PageTypes.IMAGE, PageTypes.IMAGE_AUDIO, PageTypes.BUNDLE, PageTypes.VIDEO] {

                for slot in PageAssets.slots(type: type, base: "page02", imageFormat: FileExtensions.JPG, frameCount: frames) {
                    XCTAssertTrue(union.contains(slot), "\(type) occupies \(slot.subdir)/\(slot.name), which nothing reserves")
                }

            }

        }

    }

    func testUnionListsEachFileOnce() {

        let union = PageAssets.allMediaSlots(base: "page02", imageFormat: FileExtensions.JPG, frameCount: 2)

        XCTAssertEqual(union.count, Set(union.map { "\($0.subdir)/\($0.name)" }).count)

    }

}
