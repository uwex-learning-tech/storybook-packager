//
//  ImportSkipReason.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  Why a dropped file didn't make it in, and how that is put to the person who dropped it. This is
//  the only thing they see about a file the import passed over, so each reason needs its own
//  wording, and each has to be true of the page it is said about: a caption dropped on a YouTube
//  slide used to be told the page had no video for it to attach to — said of a page whose entire
//  content is a video — which sends someone off to import an .mp4 that would destroy the slide if
//  they went and found one.
//

import Foundation

enum ImportSkipReason {

    case noPageNumber
    case captionWithoutMedia
    case captionOnStreamingSlide
    case unreadableCaption

    /// The order reasons are reported in, widest problem first.
    static let reportOrder: [ImportSkipReason] = [.noPageNumber,
                                                  .captionWithoutMedia,
                                                  .captionOnStreamingSlide,
                                                  .unreadableCaption]

    /// A run of one reads as badly as a run of many when the wording is fixed to the other, and one
    /// file tripping a reason is the common case.
    func explanation(count: Int) -> String {

        let one = count == 1

        switch self {

        case .noPageNumber:
            return one
                ? "This file name ends in no page number, so there is no page to import it onto. Number it to match the page it belongs to (for example \"…01\", \"…02\") and drop it in again."
                : "These file names end in no page number, so there is no page to import them onto. Number them to match the page they belong to (for example \"…01\", \"…02\") and drop them in again."

        case .captionWithoutMedia:
            return one
                ? "That page has no audio or video for a caption to attach to. Import the audio or video first, then drop this in again."
                : "Those pages have no audio or video for captions to attach to. Import the audio or video first, then drop these in again."

        case .captionOnStreamingSlide:
            return one
                ? "That page plays a video hosted on Kaltura, YouTube, or Vimeo. Captions for it come from the site hosting the video, not from this presentation, so add them there."
                : "Those pages play videos hosted on Kaltura, YouTube, or Vimeo. Captions for them come from the sites hosting the videos, not from this presentation, so add them there."

        case .unreadableCaption:
            return one
                ? "This caption file could not be read — it holds no captions, or it isn't a caption file at all."
                : "These caption files could not be read — they hold no captions, or they aren't caption files at all."

        }

    }

    /// The whole report: the files that hit each reason, then why. Reasons nothing was skipped for
    /// are left out entirely.
    static func report(_ skipped: Array<(file: String, reason: ImportSkipReason)>) -> String {

        return reportOrder.compactMap { reason -> String? in

            let files = skipped.filter { $0.reason == reason }.map { $0.file }

            guard !files.isEmpty else { return nil }

            return "\(files.joined(separator: ", "))\n\(reason.explanation(count: files.count))"

        }.joined(separator: "\n\n")

    }

}
