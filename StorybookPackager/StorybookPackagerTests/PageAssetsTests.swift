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

// The renumbering a save performs. Every scenario here is one that went wrong in a shipped build:
// a slide renamed out of a file its neighbour was still being renamed from, a slide handed a name it
// held nothing under, and two slides carrying one name between them.
class AssetRenameTests: XCTestCase {

    private let fmt = FileExtensions.JPG

    private func slide(_ type: String, _ src: String, frames: Int = 1) -> AssetRename.Slide {
        return AssetRename.Slide(type: type, src: src, frameCount: frames)
    }

    /// Plan against a stated set of files, written "subdir/name".
    private func plan(_ slides: [AssetRename.Slide], holding files: Set<String>) -> AssetRename.Plan {

        return AssetRename.plan(slides: slides, prefix: "page", imageFormat: fmt) {
            files.contains("\($0.subdir)/\($0.name)")
        }

    }

    private func move(_ plan: AssetRename.Plan, _ subdir: String, _ oldFile: String) -> AssetRename.Move? {
        return plan.moves.first { $0.subdir == subdir && $0.oldFile == oldFile }
    }

    // MARK: - a slide whose files are missing

    // A slide's name is its name, not a claim that its files are there. A picture can be missing for
    // any number of ordinary reasons — mid-transition, removed on purpose — and the slide still has
    // to be called page02 so the picture has somewhere to come back to. An earlier version of this
    // took the name away from a slide holding nothing, which made absence change a slide's identity.
    func testSlideWithNoFilesIsStillNamedForItsPosition() {

        let p = plan([slide(PageTypes.IMAGE, ""), slide(PageTypes.IMAGE, "page02")],
                     holding: ["pages/page02.jpg"])

        XCTAssertEqual(p.names[0], "page01")
        XCTAssertEqual(p.names[1], "page02")

    }

    // ...and the empty slot still produces a move, whose job is to clear the destination so the
    // slide cannot inherit whatever the slide previously in that position left behind.
    func testEmptySlotClearsItsDestinationRatherThanInheriting() {

        let p = plan([slide(PageTypes.IMAGE, "page03")], holding: [])

        XCTAssertEqual(p.names[0], "page01")
        XCTAssertEqual(move(p, FileNames.PAGES_DIR, "page03.jpg")?.hasSource, false)

    }

    // MARK: - two slides carrying one name

    // A package written by 1.9.9, or a bulk import onto a reordered deck, can leave two slides
    // carrying one base. Both take a copy of the shared file forward under their own new name: one
    // of them ends up wearing a picture that is not really its own, which is visible and can be put
    // right by hand. Picking a winner would blank the loser and destroy the only copy.
    func testDuplicateNameDuplicatesRatherThanDestroys() {

        let p = plan([slide(PageTypes.IMAGE, "page03"), slide(PageTypes.IMAGE, "page03")],
                     holding: ["pages/page03.jpg"])

        XCTAssertEqual(p.names[0], "page01")
        XCTAssertEqual(p.names[1], "page02")

        let moves = p.moves.filter { $0.oldFile == "page03.jpg" && $0.hasSource }

        XCTAssertEqual(moves.count, 2)
        XCTAssertTrue(moves.allSatisfy { $0.hasSource }, "neither slide may be blanked")
        XCTAssertEqual(Set(moves.map { $0.newFile }), ["page01.jpg", "page02.jpg"])

    }

    // MARK: - the swap a naive implementation breaks

    func testSwappedSlidesEachKeepTheirOwnPicture() {

        // Ordinal 1 was page02, ordinal 2 was page01 — they have been dragged past each other.
        let p = plan([slide(PageTypes.IMAGE, "page02"), slide(PageTypes.IMAGE, "page01")],
                     holding: ["pages/page01.jpg", "pages/page02.jpg"])

        XCTAssertEqual(move(p, FileNames.PAGES_DIR, "page02.jpg"),
                       AssetRename.Move(subdir: FileNames.PAGES_DIR, oldFile: "page02.jpg", newFile: "page01.jpg", hasSource: true))
        XCTAssertEqual(move(p, FileNames.PAGES_DIR, "page01.jpg"),
                       AssetRename.Move(subdir: FileNames.PAGES_DIR, oldFile: "page01.jpg", newFile: "page02.jpg", hasSource: true))

    }

    // MARK: - a slot the slide does not fill

    // The half-filled slide: it owns narration but no picture, so the picture left behind by whoever
    // sat at its new position has to be cleared rather than inherited.
    func testHalfFilledSlideKeepsItsNameAndClearsTheSlotItCannotFill() {

        let p = plan([slide(PageTypes.IMAGE_AUDIO, "page03")], holding: ["audio/page03.mp3"])

        XCTAssertEqual(p.names[0], "page01")
        XCTAssertEqual(move(p, FileNames.PAGES_DIR, "page03.jpg")?.hasSource, false)
        XCTAssertEqual(move(p, FileNames.AUDIO_DIR, "page03.mp3")?.hasSource, true)
        XCTAssertEqual(move(p, FileNames.AUDIO_DIR, "page03.vtt")?.hasSource, false)

    }

    // MARK: - numbering

    // Section rows are filtered out before planning, but quizzes and HTML widgets are not: they take
    // an ordinal without taking a name, so the numbering must count them and leave their src alone.
    func testFilelessTypesTakeAnOrdinalButKeepTheirSrc() {

        let p = plan([slide(PageTypes.QUIZ, "quiz-thing"),
                      slide(PageTypes.YOUTUBE, "dQw4w9WgXcQ"),
                      slide(PageTypes.IMAGE, "page09")],
                     holding: ["pages/page09.jpg"])

        XCTAssertNil(p.names[0])
        XCTAssertNil(p.names[1])
        XCTAssertEqual(p.names[2], "page03", "the image slide is third, so it is page03")

    }

    func testPageNumbersArePadded() {

        let slides = (1...11).map { slide(PageTypes.IMAGE, "old\($0)") }
        let p = plan(slides, holding: Set(slides.map { "pages/\($0.src).jpg" }))

        XCTAssertEqual(p.names[0], "page01")
        XCTAssertEqual(p.names[10], "page11")

    }

    // MARK: - the property that makes applying the moves in any order safe

    // Every destination is written by at most one move. Without this, applying a move could undo one
    // already applied, and the order of the loop would start to matter again.
    func testEveryDestinationIsUnique() {

        let slides = [slide(PageTypes.IMAGE, "a"),
                      slide(PageTypes.IMAGE_AUDIO, "b"),
                      slide(PageTypes.BUNDLE, "c", frames: 3),
                      slide(PageTypes.VIDEO, "d")]

        let p = plan(slides, holding: Set(slides.flatMap { s in
            PageAssets.slots(type: s.type, base: s.src, imageFormat: fmt, frameCount: s.frameCount).map { "\($0.subdir)/\($0.name)" }
        }))

        let destinations = p.moves.map { "\($0.subdir)/\($0.newFile)" }

        XCTAssertEqual(destinations.count, Set(destinations).count)

    }

    // A stable deck renames nothing at all, which is what keeps a re-save from copying every asset.
    func testResavingAnUnchangedDeckMovesNothing() {

        let p = plan([slide(PageTypes.IMAGE_AUDIO, "page01"), slide(PageTypes.IMAGE_AUDIO, "page02")],
                     holding: ["pages/page01.jpg", "audio/page01.mp3", "pages/page02.jpg", "audio/page02.mp3"])

        XCTAssertTrue(p.moves.allSatisfy { $0.oldFile == $0.newFile })
        XCTAssertEqual(p.names[0], "page01")
        XCTAssertEqual(p.names[1], "page02")

    }


    // MARK: - names this pass does not own

    // A widget slide's narration and a quiz's media live in the same directories and keep their
    // names for ever. The renumbering walks the same namespace, so it has to step around them —
    // otherwise a slide taking position 2 either writes over the widget's narration or, when it has
    // no narration of its own, deletes it as "something left behind at the name I am taking".
    func testSlideStepsAroundANameSomethingElseAnswersFor() {

        let p = AssetRename.plan(slides: [slide(PageTypes.IMAGE_AUDIO, "page07")],
                                 prefix: "page",
                                 imageFormat: fmt,
                                 spokenFor: ["audio/page01.mp3"],
                                 holdsFile: { ["pages/page07.jpg", "audio/page07.mp3"].contains("\($0.subdir)/\($0.name)") })

        XCTAssertEqual(p.names[0], "page01_copy1", "page01 is spoken for, so the slide steps aside")
        XCTAssertFalse(p.moves.contains { $0.subdir == FileNames.AUDIO_DIR && $0.newFile == "page01.mp3" },
                       "nothing may be written to, or cleared from, a name this pass does not own")

    }

}
