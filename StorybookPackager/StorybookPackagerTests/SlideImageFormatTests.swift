//
//  SlideImageFormatTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  A presentation keeps all of its slide images in one format, and every filename under
//  assets/pages/ is built from it. Reading a drop as a format change — and working out which slides
//  can follow it there — is what decides whether an author's re-exported deck goes in or whether
//  their existing slide images quietly disappear, so it is settled here rather than in the UI.
//

import XCTest
import AppKit

class SlideImageFormatTests: XCTestCase {

    private func urls(_ names: [String]) -> [URL] {
        return names.map { URL(fileURLWithPath: "/tmp/\($0)") }
    }

    // MARK: - what format a drop is

    func testABatchAllInOneFormatIsThatFormat() {

        XCTAssertEqual(SlideImageFormat.uniformFormat(of: urls(["deck01.png", "deck02.png", "deck03.png"])),
                       FileExtensions.PNG)

    }

    func testADropMixingTwoImageFormatsSettlesNoFormat() {

        XCTAssertNil(SlideImageFormat.uniformFormat(of: urls(["deck01.png", "deck02.jpg"])))

    }

    func testTheTwoSpellingsOfJpegAreOneFormat() {

        XCTAssertEqual(SlideImageFormat.uniformFormat(of: urls(["deck01.jpg", "deck02.JPEG"])),
                       FileExtensions.JPG)

    }

    // A folder of slides with their narration is still a batch of slides.
    func testNonImagesDroppedAlongsideAreIgnored() {

        XCTAssertEqual(SlideImageFormat.uniformFormat(of: urls(["deck01.svg", "deck01.mp3", "deck01.vtt", "deck02.svg"])),
                       FileExtensions.SVG)

    }

    func testADropWithNoImagesAtAllSettlesNoFormat() {

        XCTAssertNil(SlideImageFormat.uniformFormat(of: urls(["deck01.mp3", "deck02.mp3"])))

    }

    // MARK: - what it takes to get from one format to another

    func testConversionMatrix() {

        let svg = FileExtensions.SVG
        let png = FileExtensions.PNG
        let jpg = FileExtensions.JPG

        XCTAssertEqual(SlideImageFormat.conversion(from: svg, to: svg), .none)
        XCTAssertEqual(SlideImageFormat.conversion(from: png, to: png), .none)
        XCTAssertEqual(SlideImageFormat.conversion(from: jpg, to: jpg), .none)

        // The other spelling of the same format is not a conversion.
        XCTAssertEqual(SlideImageFormat.conversion(from: jpg, to: FileExtensions.JPEG), .none)

        XCTAssertEqual(SlideImageFormat.conversion(from: png, to: jpg), .transcode)
        XCTAssertEqual(SlideImageFormat.conversion(from: jpg, to: png), .transcode)

        // SVG converts in neither direction. Nothing recovers vector artwork from a picture, and
        // drawing vector artwork into pixels needs a browser engine — which made the whole
        // conversion asynchronous and cost far more in correctness than the case was worth.
        XCTAssertEqual(SlideImageFormat.conversion(from: png, to: svg), .impossible)
        XCTAssertEqual(SlideImageFormat.conversion(from: jpg, to: svg), .impossible)
        XCTAssertEqual(SlideImageFormat.conversion(from: svg, to: png), .impossible)
        XCTAssertEqual(SlideImageFormat.conversion(from: svg, to: jpg), .impossible)

    }

    // MARK: - what a switch does to the slides already there

    func testTheBatchCoversSomeSlidesAndTheRestAreConverted() {

        let plan = SlideImageFormat.plan(from: FileExtensions.PNG,
                                         to: FileExtensions.JPG,
                                         existingAssetNames: ["deck01.png", "deck02.png", "deck03.png", "deck04.png"],
                                         replacedBy: ["deck01.jpg", "deck02.jpg"])

        XCTAssertEqual(plan.replaced, ["deck01.png", "deck02.png"])
        XCTAssertEqual(plan.converted, ["deck03.png", "deck04.png"])
        XCTAssertTrue(plan.lost.isEmpty)

    }

    func testSwitchingToSvgLosesEverySlideTheBatchDoesNotCover() {

        let plan = SlideImageFormat.plan(from: FileExtensions.PNG,
                                         to: FileExtensions.SVG,
                                         existingAssetNames: ["deck01.png", "deck02.png", "deck03.png"],
                                         replacedBy: ["deck01.svg"])

        XCTAssertEqual(plan.replaced, ["deck01.png"])
        XCTAssertTrue(plan.converted.isEmpty)
        XCTAssertEqual(plan.lost, ["deck02.png", "deck03.png"])

    }

    // Switching a deck away from SVG cannot bring the drawings with it, so every slide the batch
    // doesn't cover is named as one that loses its image.
    func testLeavingSvgLosesTheSlidesTheBatchDoesNotCover() {

        let plan = SlideImageFormat.plan(from: FileExtensions.SVG,
                                         to: FileExtensions.JPG,
                                         existingAssetNames: ["deck01.svg", "deck02.svg", "deck03.svg"],
                                         replacedBy: ["deck01.jpg"])

        XCTAssertEqual(plan.replaced, ["deck01.svg"])
        XCTAssertTrue(plan.converted.isEmpty)
        XCTAssertEqual(plan.lost, ["deck02.svg", "deck03.svg"])

    }

    // A bundle's frames live in assets/pages/ under the same extension as any other slide, so they
    // have to partition the same way — a special case for them is a special case that gets missed.
    func testBundleFramesPartitionLikeAnyOtherFile() {

        let plan = SlideImageFormat.plan(from: FileExtensions.PNG,
                                         to: FileExtensions.JPG,
                                         existingAssetNames: ["deck02-1.png", "deck02-2.png", "deck03.png"],
                                         replacedBy: ["deck02-1.jpg"])

        XCTAssertEqual(plan.replaced, ["deck02-1.png"])
        XCTAssertEqual(plan.converted, ["deck02-2.png", "deck03.png"])
        XCTAssertTrue(plan.lost.isEmpty)

    }

    // Files that aren't in the presentation's format aren't the presentation's slide images.
    func testFilesInOtherFormatsAreLeftOutOfThePlan() {

        let plan = SlideImageFormat.plan(from: FileExtensions.PNG,
                                         to: FileExtensions.JPG,
                                         existingAssetNames: ["deck01.png", "stray.svg", "notes.pdf"],
                                         replacedBy: [])

        XCTAssertEqual(plan.converted, ["deck01.png"])
        XCTAssertTrue(plan.lost.isEmpty)
        XCTAssertTrue(plan.replaced.isEmpty)

    }

    // MARK: - which dropped files get a say

    // Every import is keyed by the page number the file name ends in, so a file carrying no digits
    // names no slide. Dragging one unnumbered image used to offer to convert the whole presentation
    // and then import nothing at all — on an SVG deck, every slide image gone for a file that was
    // never importable.
    func testAnImageNamingNoPageHasNoSayInTheBatchesFormat() {

        let dropped = urls(["logo.svg", "cover-image.svg"])

        XCTAssertTrue(SlideImageFormat.namingAPage(dropped).isEmpty)
        XCTAssertNil(SlideImageFormat.uniformFormat(of: SlideImageFormat.namingAPage(dropped)))

    }

    func testNumberedImagesDoHaveASay() {

        let dropped = urls(["logo.svg", "deck01.svg", "deck02.svg"])
        let placeable = SlideImageFormat.namingAPage(dropped)

        XCTAssertEqual(placeable.map { $0.lastPathComponent }, ["deck01.svg", "deck02.svg"])
        XCTAssertEqual(SlideImageFormat.uniformFormat(of: placeable), FileExtensions.SVG)

    }

    func testAnEmptyDropSettlesNoFormat() {

        XCTAssertNil(SlideImageFormat.uniformFormat(of: []))

    }

    func testUppercaseExtensionsAreTheSameFormat() {

        XCTAssertEqual(SlideImageFormat.uniformFormat(of: urls(["deck01.PNG", "deck02.png"])),
                       FileExtensions.PNG)

    }

    // A leading-dot name is all extension and no name; NSString.pathExtension reads it as neither.
    func testAFileNamedForNothingButAnExtensionIsNotAnImage() {

        XCTAssertNil(SlideImageFormat.uniformFormat(of: urls([".png"])))

    }

    // `all` is used directly as the open panel's allowed types and as the drag-accept list, so
    // "three formats, two spellings" is load-bearing in both places.
    func testJpegIsASpellingNotAFormatOfItsOwn() {

        XCTAssertEqual(SlideImageFormat.all, [FileExtensions.SVG, FileExtensions.PNG, FileExtensions.JPG])
        XCTAssertFalse(SlideImageFormat.all.contains(FileExtensions.JPEG))

        XCTAssertTrue(SlideImageFormat.isSlideImage(FileExtensions.JPEG))
        XCTAssertTrue(SlideImageFormat.isSlideImage("JPEG"))
        XCTAssertTrue(SlideImageFormat.isSlideImage("SVG"))
        XCTAssertFalse(SlideImageFormat.isSlideImage(FileExtensions.MP3))

    }

    // MARK: - more of what a switch does to the slides already there

    func testAPresentationWithNoSlideImagesPlansNothing() {

        let plan = SlideImageFormat.plan(from: FileExtensions.SVG,
                                         to: FileExtensions.PNG,
                                         existingAssetNames: [],
                                         replacedBy: [])

        XCTAssertTrue(plan.replaced.isEmpty)
        XCTAssertTrue(plan.converted.isEmpty)
        XCTAssertTrue(plan.lost.isEmpty)

    }

    func testSwitchingToTheOtherSpellingConvertsNothing() {

        let plan = SlideImageFormat.plan(from: FileExtensions.JPG,
                                         to: FileExtensions.JPEG,
                                         existingAssetNames: ["deck01.jpg", "deck02.jpg"],
                                         replacedBy: [])

        XCTAssertTrue(plan.converted.isEmpty)
        XCTAssertTrue(plan.lost.isEmpty)

    }

    // The alert uppercases these straight into its sentences, so a raw passthrough would have it
    // saying "converted from JPEG to PNG" of a presentation that has never heard of JPEG.
    func testThePlanReportsCanonicalFormats() {

        let plan = SlideImageFormat.plan(from: "JPEG",
                                         to: "PNG",
                                         existingAssetNames: ["deck01.jpg"],
                                         replacedBy: [])

        XCTAssertEqual(plan.from, FileExtensions.JPG)
        XCTAssertEqual(plan.to, FileExtensions.PNG)
        XCTAssertEqual(plan.converted, ["deck01.jpg"])

    }

    // Matching is on the whole name, not a prefix of it.
    func testANameThatMerelyStartsWithAnIncomingNameIsNotReplaced() {

        let plan = SlideImageFormat.plan(from: FileExtensions.PNG,
                                         to: FileExtensions.JPG,
                                         existingAssetNames: ["deck01.png", "deck010.png"],
                                         replacedBy: ["deck01.jpg"])

        XCTAssertEqual(plan.replaced, ["deck01.png"])
        XCTAssertEqual(plan.converted, ["deck010.png"])

    }

    // The filesystem is case-insensitive, so these are one slide, not two.
    func testANameDifferingOnlyInCaseIsTheSameSlide() {

        let plan = SlideImageFormat.plan(from: FileExtensions.SVG,
                                         to: FileExtensions.JPG,
                                         existingAssetNames: ["Deck01.svg"],
                                         replacedBy: ["deck01.jpg"])

        XCTAssertEqual(plan.replaced, ["Deck01.svg"])
        XCTAssertTrue(plan.converted.isEmpty)

    }

    // The order the alert lists them in, which is the order a reader looks for a page in.
    func testTheImagesLeftBehindAreListedInPageOrder() {

        let plan = SlideImageFormat.plan(from: FileExtensions.PNG,
                                         to: FileExtensions.SVG,
                                         existingAssetNames: ["deck10.png", "deck2.png", "deck1.png"],
                                         replacedBy: [])

        XCTAssertEqual(plan.lost, ["deck1.png", "deck2.png", "deck10.png"])

    }

    // A stray file already in the format being switched to is not the presentation's to convert.
    func testFilesAlreadyInTheTargetFormatAreLeftAlone() {

        let plan = SlideImageFormat.plan(from: FileExtensions.PNG,
                                         to: FileExtensions.JPG,
                                         existingAssetNames: ["deck01.jpg"],
                                         replacedBy: [])

        XCTAssertTrue(plan.replaced.isEmpty)
        XCTAssertTrue(plan.converted.isEmpty)
        XCTAssertTrue(plan.lost.isEmpty)

    }

}
