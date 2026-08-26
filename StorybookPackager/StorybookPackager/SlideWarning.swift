//
//  SlideWarning.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  A slide can be left in a state that is not an error anywhere — the document saves, the outline
//  looks ordinary — and yet is plainly wrong: a slide set to play narration that has no narration,
//  captions sitting beside audio that was removed out from under them. These states are made by
//  ordinary editing (retype a slide, remove a source, import over the top) and are invisible until
//  the presentation is published, so the outline marks them where the slides are listed.
//

import Cocoa

/// What the presentation actually holds for one slide, as far as its own assets go. A bundle's
/// `hasImage` means it has at least its first frame.
struct SlideInventory {

    let type: String
    let src: String
    let hasImage: Bool
    let hasAudio: Bool
    let hasVideo: Bool
    let hasCaptions: Bool

}

enum SlideWarning {

    case missingImage
    case missingAudio
    case missingVideo
    case missingVideoId
    case missingBundleImages
    case captionsWithoutAudio
    case captionsWithoutVideo

    var message: String {

        switch self {
        case .missingImage:
            return "This slide has no image."
        case .missingAudio:
            return "This slide is set to play narration, but has no audio."
        case .missingVideo:
            return "This slide is set to play a video, but has no video file."
        case .missingVideoId:
            return "This slide has no video ID, so there is no video for it to play."
        case .missingBundleImages:
            return "This bundle has no images."
        case .captionsWithoutAudio:
            return "The captions on this slide have no audio to caption."
        case .captionsWithoutVideo:
            return "The captions on this slide have no video to caption."
        }

    }

    /// Everything wrong with one slide, media first: what is missing is the cause, and a caption
    /// with nothing to caption is usually the consequence.
    static func warnings(for slide: SlideInventory) -> [SlideWarning] {

        var warnings: [SlideWarning] = []

        switch slide.type {

        case PageTypes.IMAGE:

            if !slide.hasImage { warnings.append(.missingImage) }

        case PageTypes.IMAGE_AUDIO:

            if !slide.hasImage { warnings.append(.missingImage) }
            if !slide.hasAudio { warnings.append(.missingAudio) }
            if slide.hasCaptions && !slide.hasAudio { warnings.append(.captionsWithoutAudio) }

        case PageTypes.BUNDLE:

            if !slide.hasImage { warnings.append(.missingBundleImages) }
            if !slide.hasAudio { warnings.append(.missingAudio) }
            if slide.hasCaptions && !slide.hasAudio { warnings.append(.captionsWithoutAudio) }

        case PageTypes.VIDEO:

            if !slide.hasVideo { warnings.append(.missingVideo) }
            if slide.hasCaptions && !slide.hasVideo { warnings.append(.captionsWithoutVideo) }

        case PageTypes.KALTURA, PageTypes.YOUTUBE, PageTypes.VIMEO:

            // A hosted video is named by its ID and nothing else, so an empty one is the whole slide
            // missing rather than a file missing.
            if slide.src.trimmingCharacters(in: .whitespaces).isEmpty { warnings.append(.missingVideoId) }

        default:

            // Quizzes, HTML slides, notes and section headers carry no media of this kind, so there
            // is nothing here that can be half-set.
            break

        }

        return warnings

    }

    /// The mark itself, for the row's label. Text rather than a tinted symbol image, for the same
    /// reason the caption mark is: a drawn-in colour would stay put when the window's appearance
    /// changes under it.
    static func mark(baseFont: NSFont?) -> NSAttributedString {

        let size = (baseFont?.pointSize ?? NSFont.smallSystemFontSize) + 1

        return NSAttributedString(string: "\u{26A0} ", attributes: [
            .font: NSFont.systemFont(ofSize: size),
            .foregroundColor: NSColor.systemOrange
        ])

    }

    /// The tooltip for a slide: one line per thing wrong with it.
    static func tooltip(for warnings: [SlideWarning]) -> String? {

        guard !warnings.isEmpty else { return nil }

        return warnings.map { $0.message }.joined(separator: "\n")

    }

}
