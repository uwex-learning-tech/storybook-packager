//
//  SlideImageFormatSwitchPromptTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  This question is the whole user-facing surface of a slide image format change, and answering it
//  wrongly costs the author every slide image in the presentation. Three different actions ask it —
//  a batch dropped on the page list, one image chosen for one slide, and the Page Image Type popup
//  in Properties — and a first cut described all three as an import, so someone who had just changed
//  a popup was told about "the slide images the import doesn't cover". There was no import.
//

import XCTest

class SlideImageFormatSwitchPromptTests: XCTestCase {

    private typealias Prompt = SlideImageFormatSwitchPrompt

    private func plan(from: String = FileExtensions.PNG,
                      to: String = FileExtensions.JPG,
                      existing: [String],
                      replacedBy: Set<String> = []) -> SlideImageFormat.SwitchPlan {

        return SlideImageFormat.plan(from: from, to: to, existingAssetNames: existing, replacedBy: replacedBy)

    }

    // MARK: - each action is described as the thing the author actually did

    func testThePropertiesQuestionNeverMentionsAnImport() {

        let text = Prompt.informative(for: plan(existing: ["deck01.png", "deck02.png", "deck03.png"]),
                                      context: .changingTheSetting)

        XCTAssertFalse(text.contains("import"))
        XCTAssertFalse(text.contains("Import"))

        // "other" needs something to be other than, and on this path nothing has been mentioned.
        XCTAssertFalse(text.contains("other"))

        XCTAssertTrue(text.contains("All 3 of its slide images are converted from PNG to JPG."))

    }

    func testTheBatchQuestionSaysTheImportedImagesGoInAsTheyAre() {

        let text = Prompt.informative(for: plan(existing: ["deck01.png", "deck02.png", "deck03.png"],
                                                replacedBy: ["deck01.jpg", "deck02.jpg"]),
                                      context: .importing)

        XCTAssertTrue(text.contains("The images you are importing go in as they are."))
        XCTAssertTrue(text.contains("The 1 slide image the import doesn't cover is converted from PNG to JPG."))

    }

    func testTheSetImageQuestionTalksAboutOneChosenImageNotAnImport() {

        let text = Prompt.informative(for: plan(existing: ["deck01.png", "deck02.png"],
                                                replacedBy: ["deck01.jpg"]),
                                      context: .settingOneImage)

        XCTAssertTrue(text.contains("The image you chose goes in as it is."))
        XCTAssertFalse(text.contains("import"))

        // The bug this pins: "other 1 slide image is converted".
        XCTAssertTrue(text.contains("The presentation's one other slide image is converted from PNG to JPG."))

    }

    // "Other" needs something to be other than. The sentence naming what arrives used to be skipped
    // when the chosen slide had no image yet — a fresh page, the most ordinary case there is — and
    // the next sentence was left dangling.
    func testTheSetImageQuestionSaysWhatArrivesEvenOnASlideWithNoImageYet() {

        let text = Prompt.informative(for: plan(existing: ["deck02.png", "deck03.png"]),
                                      context: .settingOneImage)

        XCTAssertTrue(text.contains("The image you chose goes in as it is."))
        XCTAssertTrue(text.contains("The presentation's other 2 slide images are converted"))

    }

    func testTheBatchQuestionSaysWhatArrivesEvenWhenNoSlideHadAnImageYet() {

        let text = Prompt.informative(for: plan(existing: ["deck04.png"], replacedBy: ["deck01.jpg", "deck02.jpg"]),
                                      context: .importing)

        XCTAssertTrue(text.contains("The images you are importing go in as they are."))

    }

    func testOneImportedImageIsWrittenAsOne() {

        let text = Prompt.informative(for: plan(existing: ["deck04.png"], replacedBy: ["deck01.jpg"]),
                                      context: .importing)

        XCTAssertTrue(text.contains("The image you are importing goes in as it is."))

    }

    // Cancelling the format question abandons the whole drop, audio and captions included. The only
    // other thing that said so was the word on the button.
    func testTheBatchQuestionSaysCancelImportsNothing() {

        let importing = Prompt.informative(for: plan(existing: ["deck01.png"], replacedBy: ["deck01.jpg"]),
                                           context: .importing)

        XCTAssertTrue(importing.contains("Cancel imports nothing at all."))

        // There is no import to abandon on the other two paths.
        let setting = Prompt.informative(for: plan(existing: ["deck01.png"]), context: .changingTheSetting)

        XCTAssertFalse(setting.contains("Cancel imports nothing"))

    }

    // MARK: - when the conversion itself fails

    // The promise this makes about Cancel has to match what the caller does with the answer: every
    // caller drops what it was going to do, so saying only that the presentation is left alone
    // would be true and still misleading.
    func testTheFailureQuestionSaysTheImportIsAbandonedToo() {

        let text = Prompt.failureInformative(count: 2, from: FileExtensions.SVG, context: .importing)

        XCTAssertTrue(text.contains("still in SVG, and imports nothing."))

    }

    func testTheFailureQuestionSaysTheChosenImageIsNotSet() {

        let text = Prompt.failureInformative(count: 1, from: FileExtensions.SVG, context: .settingOneImage)

        XCTAssertTrue(text.contains("the image you chose is not set."))
        XCTAssertTrue(text.contains("The image listed below"))
        XCTAssertFalse(text.contains("images listed below"))

    }

    func testTheFailureQuestionOnThePropertiesPathPromisesOnlyTheFormat() {

        let text = Prompt.failureInformative(count: 3, from: FileExtensions.SVG, context: .changingTheSetting)

        XCTAssertTrue(text.contains("still in SVG."))
        XCTAssertFalse(text.contains("import"))
        XCTAssertTrue(text.contains("The images listed below"))

    }

    // MARK: - the sentences themselves

    func testTheQuestionNamesBothFormatsInCapitals() {

        let text = Prompt.informative(for: plan(existing: ["deck01.png"]), context: .changingTheSetting)

        XCTAssertTrue(text.contains("PNG"))
        XCTAssertTrue(text.contains("JPG"))
        XCTAssertFalse(text.contains("png"))

    }

    func testOneImageIsWrittenAsOne() {

        let one = Prompt.informative(for: plan(existing: ["deck01.png"]), context: .changingTheSetting)

        XCTAssertTrue(one.contains("Its 1 slide image is converted"))
        XCTAssertFalse(one.contains("images are converted"))

    }

    func testOneImageLeftBehindIsWrittenAsOne() {

        let one = Prompt.informative(for: plan(from: FileExtensions.PNG,
                                               to: FileExtensions.SVG,
                                               existing: ["deck01.png"]),
                                     context: .changingTheSetting)

        XCTAssertTrue(one.contains("the image listed below"))
        XCTAssertFalse(one.contains("1 images"))

        let several = Prompt.informative(for: plan(from: FileExtensions.PNG,
                                                   to: FileExtensions.SVG,
                                                   existing: ["deck01.png", "deck02.png", "deck03.png"]),
                                         context: .changingTheSetting)

        XCTAssertTrue(several.contains("the 3 images listed below"))
        XCTAssertNotEqual(one, several)

    }

    // Switching to SVG can convert nothing, so the sentence about conversions must stay away.
    func testAnImpossibleSwitchDoesNotClaimAnythingIsConverted() {

        let text = Prompt.informative(for: plan(from: FileExtensions.PNG,
                                                to: FileExtensions.SVG,
                                                existing: ["deck01.png", "deck02.png"]),
                                      context: .changingTheSetting)

        XCTAssertFalse(text.contains("converted"))
        XCTAssertTrue(text.contains("left without one"))

    }

    // Dropping SVGs on a PNG deck loses images too; the sentence is not the Properties path's alone.
    func testImagesLeftBehindAreNamedOnTheImportPathToo() {

        let text = Prompt.informative(for: plan(from: FileExtensions.PNG,
                                                to: FileExtensions.SVG,
                                                existing: ["deck01.png", "deck02.png"],
                                                replacedBy: ["deck03.svg"]),
                                      context: .importing)

        XCTAssertTrue(text.contains("the 2 images listed below cannot come with the presentation"))

    }

    // A presentation with no slide images has nothing at stake, so it is not asked at all — which
    // means no sentence has to explain that there is nothing to convert.
    func testAPresentationWithNothingAtStakeIsNotAsked() {

        XCTAssertTrue(Prompt.confirm(plan(existing: []), context: .changingTheSetting))

    }

}
