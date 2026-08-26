//
//  VideoDropTarget.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  The rules behind dropping a single video straight onto the slide being edited, kept apart from
//  the view that draws the drop and the controller that applies it so they can be reasoned about
//  (and tested) on their own.
//
//  A drop here is nothing like the bulk import: the file name says nothing, because the slide it
//  lands on is the slide the user is looking at.
//

import Foundation

enum VideoDropTarget {

    /// The slide types whose preview accepts a dropped video. A Kaltura, YouTube, or Vimeo slide
    /// plays a video hosted elsewhere, but dropping a file on one is a plain statement of intent:
    /// this slide should play this video instead.
    static let acceptingPageTypes: Set<String> = [
        PageTypes.VIDEO, PageTypes.KALTURA, PageTypes.YOUTUBE, PageTypes.VIMEO
    ]

    static func accepts(pageType: String) -> Bool {
        return acceptingPageTypes.contains(pageType)
    }

    /// One MP4 and nothing else. Anything larger or of another kind is refused outright rather than
    /// quietly handed to the bulk import — the two drops mean different things, and a rejected drag
    /// can still be aimed at the import box.
    static func videoURL(from urls: [URL]) -> URL? {

        guard urls.count == 1,
              urls[0].pathExtension.lowercased() == FileExtensions.MP4 else { return nil }

        return urls[0]

    }

    /// Whether the captions already on a slide plausibly belong to the video being dropped on it.
    ///
    /// The only thing knowable without watching both is how long each one runs, which is enough to
    /// catch the case worth catching: captions timed to the video that was just replaced. Captions
    /// that outlive the video are wrong outright; captions that stop well before it has ended are
    /// wrong too, allowing for a trailing stretch of a video that nobody speaks over.
    ///
    /// A duration that could not be read (a video still loading, a file AVFoundation would not
    /// open) proves nothing, so it does not raise a warning.
    static func captionsFit(lastCueEnd: TimeInterval, videoDuration: TimeInterval) -> Bool {

        guard videoDuration.isFinite, videoDuration > 0 else { return true }

        if lastCueEnd > videoDuration + 0.5 { return false }

        return videoDuration - lastCueEnd <= max(2.0, videoDuration * 0.1)

    }

}
