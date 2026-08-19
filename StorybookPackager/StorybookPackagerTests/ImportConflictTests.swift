//
//  ImportConflictTests.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  A slide is either a video or an image with narration, never both. Getting this decision table
//  wrong destroys authored work silently — a batch of narration dropped over a slide that was built
//  as a video used to replace it with no warning at all.
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

    // MARK: - what counts as a conflict

    func testNarrationDroppedOnAVideoPageAsks() {

        let conflicts = ImportConflict.detect(droppedURLs: [url("narration-04.mp3")],
                                              existingPages: [4: videoPage("sb04")])

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.pageNumber, "04")
        XCTAssertEqual(conflicts.first?.existing, .video)
        XCTAssertEqual(conflicts.first?.videoName, "sb04.mp4")
        XCTAssertEqual(conflicts.first?.audioName, "narration-04.mp3")

    }

    func testVideoDroppedOnAnImageAudioPageAsks() {

        let conflicts = ImportConflict.detect(droppedURLs: [url("lecture04.mp4")],
                                              existingPages: [4: imageAudioPage("sb04")])

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.existing, .audio)
        XCTAssertEqual(conflicts.first?.audioName, "sb04.mp3")

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

    // MARK: - defaults and resolution

    func testDefaultsToKeepingWhateverThePageAlreadyIs() {

        let ontoVideo = ImportConflict.detect(droppedURLs: [url("narration04.mp3")], existingPages: [4: videoPage("sb04")])
        XCTAssertEqual(ontoVideo.first?.resolution, .video)

        let ontoAudio = ImportConflict.detect(droppedURLs: [url("lecture04.mp4")], existingPages: [4: imageAudioPage("sb04")])
        XCTAssertEqual(ontoAudio.first?.resolution, .audio)

        // Both dropped onto an existing video page: the authored side still wins by default.
        let both = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")],
                                         existingPages: [4: videoPage("sb04")])
        XCTAssertEqual(both.first?.resolution, .video)

        // Nothing authored to protect — an image with narration is the ordinary slide.
        let new = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")], existingPages: [:])
        XCTAssertEqual(new.first?.resolution, .audio)

    }

    func testTheLosingSideIsTheDroppedFileThatIsSuppressed() {

        var conflict = ImportConflict.detect(droppedURLs: [url("narration04.mp3")],
                                             existingPages: [4: videoPage("sb04")]).first!

        // Keeping the video means the dropped narration is not imported.
        XCTAssertEqual(conflict.suppressedURL, url("narration04.mp3"))

        // Choosing the audio suppresses nothing, because the video it replaces was never a dropped
        // file — the page simply becomes an image+audio slide.
        conflict.resolution = .audio
        XCTAssertNil(conflict.suppressedURL)

    }

    func testChoosingOneOfTwoDroppedFilesSuppressesTheOther() {

        var conflict = ImportConflict.detect(droppedURLs: [url("narration04.mp3"), url("lecture04.mp4")],
                                             existingPages: [:]).first!

        XCTAssertEqual(conflict.suppressedURL, url("lecture04.mp4"))

        conflict.resolution = .video
        XCTAssertEqual(conflict.suppressedURL, url("narration04.mp3"))

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

}
