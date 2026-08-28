//
//  ImportConflictTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  A slide holds one kind of media, never two. Getting this decision table wrong destroys authored
//  work silently — a batch of narration dropped over a slide that was built as a video used to
//  replace it with no warning at all. Getting the dialog's wording wrong destroys it just as
//  thoroughly, so the option titles are tested too: every row must default to changing nothing.
//

import XCTest

class ImportConflictTests: XCTestCase {

    private func url(_ name: String) -> URL {
        return URL(fileURLWithPath: "/tmp/\(name)")
    }

    private func imageAudioPage(_ src: String) -> ImportConflict.ExistingPage {
        return ImportConflict.ExistingPage(type: PageTypes.IMAGE_AUDIO, src: src)
    }

    private func videoPage(_ src: String) -> ImportConflict.ExistingPage {
        return ImportConflict.ExistingPage(type: PageTypes.VIDEO, src: src)
    }

    private func streamingPage(_ type: String, _ src: String) -> ImportConflict.ExistingPage {
        return ImportConflict.ExistingPage(type: type, src: src)
    }

    // MARK: - what counts as a conflict

    func testNarrationDroppedOnAVideoPageAsks() {

        let conflicts = ImportConflict.detect(droppedURLs: [url("narration-04.mp3")],
                                              existingPages: [4: videoPage("sb04")])

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.pageNumber, "04")
        XCTAssertEqual(conflicts.first?.existing, .video)
        XCTAssertEqual(conflicts.first?.keptName, "sb04.mp4")
        XCTAssertEqual(conflicts.first?.audioName, "narration-04.mp3")

    }

    func testVideoDroppedOnAnImageAudioPageAsks() {

        let conflicts = ImportConflict.detect(droppedURLs: [url("lecture04.mp4")],
                                              existingPages: [4: imageAudioPage("sb04")])

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.existing, .audio)
        XCTAssertEqual(conflicts.first?.keptName, "sb04.mp3")

    }

    func testVideoDroppedOnABundlePageAsks() {

        // A bundle is narration plus a run of images — as much authored work to lose as any.
        let bundle = ImportConflict.ExistingPage(type: PageTypes.BUNDLE, src: "sb04")

        XCTAssertEqual(ImportConflict.detect(droppedURLs: [url("lecture04.mp4")], existingPages: [4: bundle]).count, 1)

    }

    func testBothDroppedForOnePageAsksEvenWhenThePageIsNew() {

        let conflicts = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")],
                                              existingPages: [:])

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertNil(conflicts.first?.existing)
        XCTAssertNotNil(conflicts.first?.videoURL)
        XCTAssertNotNil(conflicts.first?.audioURL)

    }

    // MARK: - what must not interrupt

    func testNothingToLoseDoesNotAsk() {

        let image = ImportConflict.ExistingPage(type: PageTypes.IMAGE, src: "sb04")

        // Narration onto a plain image page only adds to it.
        XCTAssertTrue(ImportConflict.detect(droppedURLs: [url("narration04.mp3")], existingPages: [4: image]).isEmpty)

        // Narration onto a page that is already image+audio just replaces its own kind.
        XCTAssertTrue(ImportConflict.detect(droppedURLs: [url("narration04.mp3")], existingPages: [4: imageAudioPage("sb04")]).isEmpty)

        // Video onto a page that is already video, likewise.
        XCTAssertTrue(ImportConflict.detect(droppedURLs: [url("lecture04.mp4")], existingPages: [4: videoPage("sb04")]).isEmpty)

        // Pages the drop doesn't touch are irrelevant.
        XCTAssertTrue(ImportConflict.detect(droppedURLs: [url("slide04.jpg")], existingPages: [4: videoPage("sb04")]).isEmpty)

    }

    func testOnlyTheCollidingPagesOfALargeBatchAsk() {

        // The case that prompted this: a folder of narration where one slide was authored as video.
        let dropped = (1...6).map { url("narration0\($0).mp3") }

        let existing: [Int: ImportConflict.ExistingPage] = [
            1: imageAudioPage("sb01"),
            2: imageAudioPage("sb02"),
            3: videoPage("sb03"),
            4: imageAudioPage("sb04"),
            5: videoPage("sb05"),
            6: imageAudioPage("sb06")
        ]

        let conflicts = ImportConflict.detect(droppedURLs: dropped, existingPages: existing)

        XCTAssertEqual(conflicts.map { $0.pageNumber }, ["03", "05"])

    }

    // MARK: - the dialog changes nothing on its own

    func testEveryPageWithSomethingToLoseOpensOnKeepingIt() {

        let ontoVideo = ImportConflict.detect(droppedURLs: [url("narration04.mp3")], existingPages: [4: videoPage("sb04")])
        XCTAssertEqual(ontoVideo.first?.resolution, .keep)
        XCTAssertEqual(ontoVideo.first?.options.first, .keep)

        let ontoAudio = ImportConflict.detect(droppedURLs: [url("lecture04.mp4")], existingPages: [4: imageAudioPage("sb04")])
        XCTAssertEqual(ontoAudio.first?.resolution, .keep)

        // Both dropped onto an authored page: keeping what is there is still a choice, and still
        // the one the dialog opens on.
        let both = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")],
                                         existingPages: [4: videoPage("sb04")])
        XCTAssertEqual(both.first?.options, [.keep, .video, .audio])
        XCTAssertEqual(both.first?.resolution, .keep)

        // Nothing authored to protect — an image with narration is the ordinary slide.
        let new = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")], existingPages: [:])
        XCTAssertEqual(new.first?.options, [.audio, .video])
        XCTAssertEqual(new.first?.resolution, .audio)

    }

    func testKeepingAPageImportsNoneOfTheFilesDroppedForIt() {

        var conflict = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")],
                                             existingPages: [4: videoPage("sb04")]).first!

        XCTAssertEqual(Set(conflict.suppressedURLs), Set([url("narration04.mp3"), url("lecture04.mp4")]))

        // Choosing a replacement imports that file and leaves the other out.
        conflict.resolution = .audio
        XCTAssertEqual(conflict.suppressedURLs, [url("lecture04.mp4")])

        conflict.resolution = .video
        XCTAssertEqual(conflict.suppressedURLs, [url("narration04.mp3")])

    }

    func testChoosingOneOfTwoDroppedFilesSuppressesTheOther() {

        var conflict = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")],
                                             existingPages: [:]).first!

        XCTAssertEqual(conflict.suppressedURLs, [url("lecture04.mp4")])

        conflict.resolution = .video
        XCTAssertEqual(conflict.suppressedURLs, [url("narration04.mp3")])

    }

    // MARK: - how the rows read

    // Each row is read on its own, so an option has to say what it does without leaning on the text
    // above the list. The dialog this replaced offered one checkbox per row whose meaning lived in
    // that paragraph, and it was read as a replacement to decline: clearing the box chose the very
    // replacement it was meant to refuse.

    func testTheOptionsSayWhatTheyDo() {

        let ontoVideo = ImportConflict.detect(droppedURLs: [url("narration04.mp3")],
                                              existingPages: [4: videoPage("sb04")]).first!

        XCTAssertEqual(ontoVideo.options, [.keep, .audio])
        XCTAssertEqual(ontoVideo.choiceTitle(for: .keep), "Keep sb04.mp4")
        XCTAssertEqual(ontoVideo.choiceTitle(for: .audio), "Replace with narration04.mp3")

        // Nothing is being replaced on a page that doesn't exist yet, so neither option says it is.
        let new = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")],
                                        existingPages: [:]).first!

        XCTAssertEqual(new.choiceTitle(for: .audio), "Use narration04.mp3")
        XCTAssertEqual(new.choiceTitle(for: .video), "Use lecture04.mp4")

    }

    // MARK: - streaming slides

    // A Kaltura, YouTube, or Vimeo slide holds nothing but the ID of a video on someone else's
    // server. Anything imported onto it writes that ID away, and the presentation has no copy to
    // restore it from — so both an .mp3 and an .mp4 are worth asking about, including the .mp4 that
    // on an ordinary video page would be an unremarkable swap.

    func testNarrationDroppedOnAStreamingPageAsks() {

        for type in [PageTypes.KALTURA, PageTypes.YOUTUBE, PageTypes.VIMEO] {

            let conflicts = ImportConflict.detect(droppedURLs: [url("narration04.mp3")],
                                                  existingPages: [4: streamingPage(type, "0_ab12cd34")])

            XCTAssertEqual(conflicts.count, 1, "type: \(type)")
            XCTAssertEqual(conflicts.first?.existing, .streaming, "type: \(type)")
            XCTAssertEqual(conflicts.first?.resolution, .keep, "type: \(type)")

        }

    }

    func testVideoDroppedOnAStreamingPageAsksEvenThoughBothAreVideo() {

        let conflicts = ImportConflict.detect(droppedURLs: [url("lecture04.mp4")],
                                              existingPages: [4: streamingPage(PageTypes.KALTURA, "0_ab12cd34")])

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.existing, .streaming)
        XCTAssertEqual(conflicts.first?.resolution, .keep)

    }

    func testAStreamingSlideIsNamedByItsPlatformAndId() {

        let vimeo = ImportConflict.detect(droppedURLs: [url("narration04.mp3")],
                                          existingPages: [4: streamingPage(PageTypes.VIMEO, "123456")]).first!

        XCTAssertEqual(vimeo.options, [.keep, .audio])
        XCTAssertEqual(vimeo.choiceTitle(for: .keep), "Keep Vimeo 123456")

        let youtube = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")],
                                            existingPages: [4: streamingPage(PageTypes.YOUTUBE, "dQw4w9WgXcQ")]).first!

        XCTAssertEqual(youtube.options, [.keep, .video, .audio])
        XCTAssertEqual(youtube.choiceTitle(for: .keep), "Keep YouTube dQw4w9WgXcQ")

        // A streaming slide whose ID hasn't been filled in yet still has to read as something.
        let empty = ImportConflict.detect(droppedURLs: [url("narration04.mp3")],
                                          existingPages: [4: streamingPage(PageTypes.KALTURA, "")]).first!

        XCTAssertEqual(empty.choiceTitle(for: .keep), "Keep Kaltura video")

    }

    func testKeepingAStreamingVideoImportsNeitherDroppedFile() {

        let conflict = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")],
                                             existingPages: [4: streamingPage(PageTypes.KALTURA, "0_ab12cd34")]).first!

        XCTAssertEqual(Set(conflict.suppressedURLs), Set([url("narration04.mp3"), url("lecture04.mp4")]))

    }

    // MARK: - page numbering

    func testPageNumberIsReadTheSameWayTheImportReadsIt() {

        // Single digit pads, and a bundle's frame suffix never reaches the page number.
        let padded = ImportConflict.detect(droppedURLs: [url("narration4.mp3")], existingPages: [4: videoPage("sb04")])
        XCTAssertEqual(padded.first?.pageNumber, "04")

        let threeDigit = ImportConflict.detect(droppedURLs: [url("narration100.mp3")], existingPages: [100: videoPage("sb100")])
        XCTAssertEqual(threeDigit.first?.pageNumber, "100")

    }

    func testFileWithNoPageNumberIsIgnoredRatherThanCollidingWithPageZero() {

        XCTAssertTrue(ImportConflict.detect(droppedURLs: [url("narration.mp3")], existingPages: [4: videoPage("sb04")]).isEmpty)

    }

    // MARK: - the sheet's list

    func testEachRowOpensOnItsFirstOption() {

        let conflict = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")],
                                             existingPages: [4: streamingPage(PageTypes.KALTURA, "0_ab12cd34")]).first!

        let popUp = ImportConflictPrompt.popUp(for: conflict)

        XCTAssertEqual(popUp.numberOfItems, 3)
        XCTAssertEqual(popUp.indexOfSelectedItem, 0)
        XCTAssertEqual(popUp.titleOfSelectedItem, "Keep Kaltura 0_ab12cd34")

    }

    func testReplaceAllSetsEveryRowThatOffersASingleReplacement() {

        // The case the button exists for: a folder of narration dropped over slides authored as video.
        let dropped = (1...3).map { url("narration0\($0).mp3") }
        let existing: [Int: ImportConflict.ExistingPage] = [1: videoPage("sb01"), 2: videoPage("sb02"), 3: videoPage("sb03")]

        let conflicts = ImportConflict.detect(droppedURLs: dropped, existingPages: existing)
        let popUps = conflicts.map { ImportConflictPrompt.popUp(for: $0) }

        guard let actions = ImportConflictPrompt.bulkActions(for: conflicts, popUps: popUps) else {
            return XCTFail("a list of three replaceable slides is exactly what the buttons are for")
        }

        actions.replaceAll()

        XCTAssertEqual(popUps.map { $0.titleOfSelectedItem },
                       ["Replace with narration01.mp3", "Replace with narration02.mp3", "Replace with narration03.mp3"])

        // And back again, because a misclick here would otherwise cost as many menu picks as there
        // are slides.
        actions.keepAll()

        XCTAssertEqual(popUps.map { $0.titleOfSelectedItem }, ["Keep sb01.mp4", "Keep sb02.mp4", "Keep sb03.mp4"])

    }

    func testReplaceAllLeavesRowsThatNeedARealDecision() {

        // Page 02 has both an .mp3 and an .mp4 dropped on it: no blanket button can pick between them.
        let dropped = [url("narration01.mp3"), url("narration02.mp3"), url("lecture02.mp4")]
        let existing: [Int: ImportConflict.ExistingPage] = [1: videoPage("sb01"), 2: videoPage("sb02")]

        let conflicts = ImportConflict.detect(droppedURLs: dropped, existingPages: existing)
        let popUps = conflicts.map { ImportConflictPrompt.popUp(for: $0) }

        XCTAssertNil(conflicts.last?.singleReplacement)

        ImportConflictPrompt.bulkActions(for: conflicts, popUps: popUps)?.replaceAll()

        XCTAssertEqual(popUps.map { $0.titleOfSelectedItem }, ["Replace with narration01.mp3", "Keep sb02.mp4"])

    }

    func testTheBulkButtonsAreLeftOutWhenTheyWouldHaveNothingToDo() {

        // One slide is no faster to set with a button than with its own menu.
        let single = ImportConflict.detect(droppedURLs: [url("narration04.mp3")], existingPages: [4: videoPage("sb04")])
        XCTAssertNil(ImportConflictPrompt.bulkActions(for: single, popUps: single.map { ImportConflictPrompt.popUp(for: $0) }))

        // Neither is a list where every slide needs a decision of its own.
        let undecidable = ImportConflict.detect(droppedURLs: [url("narration01.mp3"), url("lecture01.mp4"),
                                                              url("narration02.mp3"), url("lecture02.mp4")],
                                                existingPages: [1: videoPage("sb01"), 2: videoPage("sb02")])

        XCTAssertEqual(undecidable.count, 2)
        XCTAssertNil(ImportConflictPrompt.bulkActions(for: undecidable, popUps: undecidable.map { ImportConflictPrompt.popUp(for: $0) }))

    }

    func testShortListIsShownWholeWithoutScrolling() {

        let rows = (1...3).map { NSButton(checkboxWithTitle: "Page 0\($0)", target: nil, action: nil) }

        XCTAssertFalse(ImportConflictPrompt.accessoryView(for: rows) is NSScrollView)

    }

    func testLongListScrollsAndOpensAtTheFirstPageNotTheLast() {

        let rows = (1...40).map { NSButton(checkboxWithTitle: "Page \($0)", target: nil, action: nil) }

        guard let scrollView = ImportConflictPrompt.accessoryView(for: rows) as? NSScrollView else {
            return XCTFail("a list this long has to scroll rather than grow the alert off-screen")
        }

        // A scroll view shows whatever sits at its document view's origin. Unflipped, that origin is
        // the bottom left, so the list would open scrolled past the first rows.
        XCTAssertEqual(scrollView.documentView?.isFlipped, true)
        XCTAssertGreaterThan(scrollView.documentView?.frame.height ?? 0, scrollView.frame.height)

    }


    // MARK: - a slide that holds nothing

    // A slide is set to play narration long before it has any: that is the ordinary state of a deck
    // an author is halfway through, and a brand-new presentation is nothing but such slides. Judged
    // on the slide's type alone, every video dropped on one raised a question about narration that
    // did not exist — and the default answer, "keep it", threw the dropped file away.
    func testSlideHoldingNoAudioLosesNothingToADroppedVideo() {

        let empty = ImportConflict.ExistingPage(type: PageTypes.IMAGE_AUDIO, src: "", holdsMedia: false)

        let conflicts = ImportConflict.detect(droppedURLs: [URL(fileURLWithPath: "/tmp/page01.mp4")],
                                              existingPages: [1: empty])

        XCTAssertTrue(conflicts.isEmpty)

    }

    // A bundle with frames but no narration recorded yet has a great deal to lose to a dropped
    // video: it is retyped, and every frame is swept at the next save. Asked only about its .mp3 it
    // reported nothing to lose, and the question that used to be asked stopped being asked.
    func testSlideHoldingFramesButNoNarrationStillRaisesTheQuestion() {

        let bundle = ImportConflict.ExistingPage(type: PageTypes.BUNDLE, src: "page03", holdsMedia: true)

        let conflicts = ImportConflict.detect(droppedURLs: [URL(fileURLWithPath: "/tmp/page03.mp4")],
                                              existingPages: [3: bundle])

        XCTAssertEqual(conflicts.count, 1)

    }

    func testSlideThatDoesHoldAudioStillRaisesTheQuestion() {

        let held = ImportConflict.ExistingPage(type: PageTypes.IMAGE_AUDIO, src: "page01", holdsMedia: true)

        let conflicts = ImportConflict.detect(droppedURLs: [URL(fileURLWithPath: "/tmp/page01.mp4")],
                                              existingPages: [1: held])

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.keptName, "page01.mp3")

    }

}
