//
//  PageRetype.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  What changing a slide's type costs, and what has to be reconciled when it goes ahead.
//
//  A slide's `src` means three different things depending on what the slide is: a base name that its
//  media files are built from, a streaming video's ID, or the name of embedded content under
//  assets/html/. Changing the type between those groups changes what `src` *means* while leaving the
//  string alone, which is how a slide came to publish "page02" as a YouTube ID, and how a deck's
//  narration came to be swept because the slide that owned it was briefly something else.
//
//  Nothing here touches the document: it is given what the slide holds and answers what would be
//  lost and what must be cleared, so the question the user is asked and the state left behind after
//  they answer are decided in one place.
//

import Foundation

enum PageRetype {

    /// The three incompatible readings of `src`, plus the types that carry none.
    enum Group {

        case media          // image, image-audio, bundle, video — src is a file base name
        case streaming      // youtube, vimeo, kaltura — src is a video ID
        case embedded       // html — src names content under assets/html/
        case quiz
        case none           // section, and anything unrecognised

        static func of(_ type: String) -> Group {

            switch type {
            case PageTypes.IMAGE, PageTypes.IMAGE_AUDIO, PageTypes.BUNDLE, PageTypes.VIDEO:
                return .media
            case PageTypes.YOUTUBE, PageTypes.VIMEO, PageTypes.KALTURA:
                return .streaming
            case PageTypes.HTML:
                return .embedded
            case PageTypes.QUIZ, PageTypes.SHORT_ANSWER, PageTypes.FILL_IN_THE_BLANK,
                 PageTypes.MULTIPLE_CHOICE, PageTypes.MULTIPLE_ANSWER:
                return .quiz
            default:
                return .none
            }

        }

    }

    /// What the change would cost, and what the slide has to give up for the new type to make sense.
    struct Impact: Equatable {

        /// Files the slide holds now that the new type does not name. Display names, in order.
        var losesFiles: [String] = []
        /// The streaming ID is not recoverable from the presentation, so it counts as content.
        var losesVideoId = false
        /// The slide stops pointing at its content under assets/html/. The folder itself is left.
        var losesEmbeddedContent = false
        /// The quiz's question, answers and their media stop being reachable.
        var losesQuiz = false

        /// `src` means something else to the new type, so carrying it over would be a lie.
        var clearsSrc = false
        /// Only an HTML slide keeps narration in its own reference.
        var clearsAudio = false
        /// Only a bundle has frames.
        var clearsFrames = false

        /// Whether the change costs the author something they cannot get back from the presentation.
        var isDestructive: Bool {
            return !losesFiles.isEmpty || losesVideoId || losesEmbeddedContent || losesQuiz
        }

    }

    /// Work out the impact. `holdsFile` is asked about the slide's current files only.
    static func impact(from: String,
                       to: String,
                       src: String,
                       audio: String,
                       frameCount: Int,
                       imageFormat: String,
                       holdsFile: (PageAssets.Slot) -> Bool) -> Impact {

        var impact = Impact()

        guard from != to else { return impact }

        let before = Group.of(from)
        let after = Group.of(to)

        // Files the slide holds now that the new type has no slot for. Within the media group this
        // is the whole cost — an image + audio slide made an image slide keeps its picture and loses
        // its narration — and it is a real cost, because the next save sweeps what nothing names.
        if !src.isEmpty {

            let held = PageAssets.slots(type: from, base: src, imageFormat: imageFormat, frameCount: frameCount).filter(holdsFile)
            let kept = Set(PageAssets.slots(type: to, base: src, imageFormat: imageFormat, frameCount: frameCount).map { $0.subdir + "/" + $0.name })

            impact.losesFiles = held.filter { !kept.contains($0.subdir + "/" + $0.name) }.map { $0.name }

        }

        // Worked out before the same-group return: bundle → image stays inside the media group, and
        // a frame list left on a slide that is no longer a bundle is still written to the XML.
        impact.clearsFrames = from == PageTypes.BUNDLE && to != PageTypes.BUNDLE

        guard before != after else { return impact }

        // Crossing between groups: whatever `src` and the rest meant, it does not mean it any more.
        impact.clearsSrc = !src.isEmpty
        impact.losesVideoId = before == .streaming && !src.isEmpty
        impact.losesEmbeddedContent = before == .embedded && !src.isEmpty
        impact.losesQuiz = before == .quiz
        impact.clearsAudio = before == .embedded && !audio.isEmpty

        if before == .embedded && !audio.isEmpty {
            impact.losesFiles.append((audio as NSString).lastPathComponent)
        }

        return impact

    }

    /// The question to put to the author, or nil when the change costs nothing.
    static func confirmation(_ impact: Impact, slideNumber: Int) -> (message: String, detail: String)? {

        guard impact.isDestructive else { return nil }

        var reasons: [String] = []

        if !impact.losesFiles.isEmpty {
            reasons.append("\(impact.losesFiles.joined(separator: ", ")) \(impact.losesFiles.count == 1 ? "is" : "are") dropped from the presentation when it is next saved.")
        }

        if impact.losesVideoId {
            reasons.append("The video ID this slide plays is not kept anywhere else, so it cannot be got back from the presentation.")
        }

        if impact.losesEmbeddedContent {
            reasons.append("The slide stops pointing at the page it embeds. That content stays in the presentation's html folder, but nothing in the editor can attach it again.")
        }

        if impact.losesQuiz {
            reasons.append("The question, its answers and any images or audio on them are no longer part of the slide.")
        }

        reasons.append("The file you imported each of these from is left where it is.")

        return ("Change the type of page \(slideNumber)?", reasons.joined(separator: "\n\n"))

    }

}
