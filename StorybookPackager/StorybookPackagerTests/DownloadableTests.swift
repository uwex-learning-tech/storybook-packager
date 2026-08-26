//
//  DownloadableTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  The files at the root of a package are found by name alone — nothing in the XML records them —
//  so the naming rules here are the whole contract with the player. A transcript can now be a PDF
//  or a web page, which puts a second file ending in ".html" beside the one that IS the
//  presentation.
//

import XCTest

class DownloadableTests: XCTestCase {

    func testATranscriptIsEitherAPdfOrAWebPage() {

        XCTAssertTrue(Downloadable.isTranscript(FileExtensions.PDF))
        XCTAssertTrue(Downloadable.isTranscript(FileExtensions.HTML))

        // Case as typed by whoever named the file, not as the app would have named it.
        XCTAssertTrue(Downloadable.isTranscript("PDF"))
        XCTAssertTrue(Downloadable.isTranscript("HTML"))

        XCTAssertFalse(Downloadable.isTranscript(FileExtensions.MP3))
        XCTAssertFalse(Downloadable.isTranscript(FileExtensions.ZIP))

    }

    func testEveryDownloadableIsNamedForItsDocument() {

        XCTAssertEqual(Downloadable.fileName(documentName: "BIO-101", ext: FileExtensions.HTML), "BIO-101.html")
        XCTAssertEqual(Downloadable.fileName(documentName: "BIO-101", ext: "PDF"), "BIO-101.pdf")

    }

    func testTheTranscriptSlotHoldsOneFormAtATime() {

        let root = ["BIO-101.pdf", "BIO-101.mp3", "index.html"]

        XCTAssertEqual(Downloadable.transcriptExtension(inRootNames: root, documentName: "BIO-101"), FileExtensions.PDF)

        let web = ["BIO-101.html", "BIO-101.zip", "index.html"]

        XCTAssertEqual(Downloadable.transcriptExtension(inRootNames: web, documentName: "BIO-101"), FileExtensions.HTML)

        // The player's own index.html is not this presentation's transcript.
        XCTAssertNil(Downloadable.transcriptExtension(inRootNames: ["index.html", "BIO-101.mp4"], documentName: "BIO-101"))

        XCTAssertNil(Downloadable.transcriptExtension(inRootNames: [], documentName: "BIO-101"))

    }

    func testClearingTheSlotUsesTheNameTheFileIsActuallyStoredUnder() {

        // Removing is an exact-name operation on the package, while the lookup that decides a
        // transcript is there matches case-insensitively. Handed the name the app *would* have
        // chosen, Remove silently does nothing and the next file set leaves two transcripts behind.
        let root = ["bio-101.pdf", "BIO-101.mp3", "index.html"]

        XCTAssertEqual(Downloadable.transcriptRootNames(inRootNames: root, documentName: "BIO-101"), ["bio-101.pdf"])

        // Both forms, both swept — that is what setting a new transcript does first.
        let both = ["BIO-101.pdf", "BIO-101.html"]
        XCTAssertEqual(Set(Downloadable.transcriptRootNames(inRootNames: both, documentName: "BIO-101")), Set(both))

        // And never the player, whatever the presentation is called.
        XCTAssertTrue(Downloadable.transcriptRootNames(inRootNames: ["index.html"], documentName: "index").isEmpty)

    }

    func testATranscriptIsFoundWhateverCaseItWasNamedIn() {

        // The case the feature's own commit message claimed to have fixed, never actually tested:
        // it is the *document* name's case that differs, not the extension's.
        XCTAssertEqual(Downloadable.transcriptExtension(inRootNames: ["bio-101.pdf"], documentName: "BIO-101"),
                       FileExtensions.PDF)

        XCTAssertEqual(Downloadable.transcriptExtension(inRootNames: ["MyDoc.HTML"], documentName: "mydoc"),
                       FileExtensions.HTML)

    }

    func testIndexHtmlIsNeverTreatedAsADownload() {

        // It ends in .html like a web transcript does. Renamed to the document's name on open — as
        // every other root file is — the package would stop opening in a browser altogether.
        XCTAssertFalse(Downloadable.isDownloadable(rootFileName: "index.html"))
        XCTAssertFalse(Downloadable.isDownloadable(rootFileName: "INDEX.HTML"))

        XCTAssertTrue(Downloadable.isDownloadable(rootFileName: "transcript.html"))
        XCTAssertTrue(Downloadable.isDownloadable(rootFileName: "BIO-101.html"))

    }

    func testAPresentationNamedIndexCannotTakeAWebTranscript() {

        // Its transcript would be called index.html — the presentation's own entry point. The
        // bundled player is only restored into a package that has none, so writing a transcript
        // there replaces the presentation permanently rather than until the next save.
        XCTAssertFalse(Downloadable.canName(transcript: FileExtensions.HTML, documentName: "index"))
        XCTAssertFalse(Downloadable.canName(transcript: FileExtensions.HTML, documentName: "INDEX"))

        // A PDF for the same presentation is index.pdf, which collides with nothing.
        XCTAssertTrue(Downloadable.canName(transcript: FileExtensions.PDF, documentName: "index"))

        // Every other name is fine in either form.
        XCTAssertTrue(Downloadable.canName(transcript: FileExtensions.HTML, documentName: "BIO-101"))
        XCTAssertTrue(Downloadable.canName(transcript: FileExtensions.HTML, documentName: "index-of-terms"))

    }

    func testThePlayerIsNeverReadAsAPresentationsOwnTranscript() {

        // For a presentation named "index" the player's index.html matches what a web transcript
        // would be called. Read as a transcript, the Files dialog would show one that isn't there
        // and its Remove button would take the presentation out.
        XCTAssertNil(Downloadable.transcriptExtension(inRootNames: ["index.html", "index.mp3"], documentName: "index"))

        // Its PDF transcript is index.pdf, which is a transcript like any other.
        XCTAssertEqual(Downloadable.transcriptExtension(inRootNames: ["index.html", "index.pdf"], documentName: "index"),
                       FileExtensions.PDF)

    }

    func testSweepingTheTranscriptSlotNeverReachesThePlayer() {

        // Every path that clears the slot builds its names from here, so a presentation named
        // "index" must not be handed index.html to delete.
        XCTAssertEqual(Downloadable.transcriptFileNames(documentName: "index"), ["index.pdf"])

        XCTAssertEqual(Downloadable.transcriptFileNames(documentName: "BIO-101"), ["BIO-101.pdf", "BIO-101.html"])

    }

    func testOnlyTheKnownKindsRideAlongAtTheRoot() {

        XCTAssertTrue(Downloadable.isDownloadable(rootFileName: "anything.pdf"))
        XCTAssertTrue(Downloadable.isDownloadable(rootFileName: "anything.mp3"))
        XCTAssertTrue(Downloadable.isDownloadable(rootFileName: "anything.mp4"))
        XCTAssertTrue(Downloadable.isDownloadable(rootFileName: "anything.zip"))

        XCTAssertFalse(Downloadable.isDownloadable(rootFileName: "sbplus.xml"))
        XCTAssertFalse(Downloadable.isDownloadable(rootFileName: "README"), "a name with no extension is not a download")
        XCTAssertFalse(Downloadable.isDownloadable(rootFileName: "assets"), "the assets directory is not a download")
        XCTAssertTrue(Downloadable.isDownloadable(rootFileName: "Notes.PDF"), "case is the file's business, not ours")
        XCTAssertFalse(Downloadable.isDownloadable(rootFileName: "notes.txt"))
        XCTAssertFalse(Downloadable.isDownloadable(rootFileName: "slide01.jpg"))

    }

    func testTheTranscriptFormsAreOfferedPdfFirst() {

        // A file panel lists them in this order, and these have overwhelmingly been PDFs.
        XCTAssertEqual(Downloadable.transcriptExtensions, [FileExtensions.PDF, FileExtensions.HTML])
        XCTAssertEqual(Set(Downloadable.allExtensions).count, 5)

    }

}
