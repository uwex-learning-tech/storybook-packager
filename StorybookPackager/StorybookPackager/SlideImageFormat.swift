//
//  SlideImageFormat.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  A presentation holds one slide image format for all of its pages, and every filename under
//  assets/pages/ is built from it — the outline thumbnail, the editor, save-time renaming, deletion,
//  paste and the orphan sweep all construct `src + "." + pageImgFormat`. So an author who
//  re-exported their deck from SVG to JPEG has no way in: the images can't go in one at a time, and
//  changing the format on its own turns every file already in assets/pages/ into an orphan that the
//  next save trashes.
//
//  This is the decision half of letting a batch of images carry the presentation to its own format:
//  what format a drop is, whether the existing slides can follow it there, and which of them can't.
//  No UI and no file access, so it can be reasoned about — and tested — on its own.
//

import Foundation

enum SlideImageFormat {

    /// The formats a slide image can be stored in. ".jpeg" is not among them: it is the other
    /// spelling of ".jpg", folded down by Util.canonicalImageExt everywhere.
    static let all = [FileExtensions.SVG, FileExtensions.PNG, FileExtensions.JPG]

    /// Whether a file extension names a slide image, in either spelling.
    static func isSlideImage(_ ext: String) -> Bool {
        return all.contains(Util.shared.canonicalImageExt(ext))
    }

    /// The formats this presentation's slide images can actually be moved to. Only the raster
    /// formats can follow each other; SVG is a one-way door in both directions (see
    /// Conversion.impossible), so an SVG presentation has nowhere to go and neither PNG nor JPG can
    /// go to SVG. Offering those anyway meant picking a format from a popup and then being told, in
    /// the next alert, that every slide in the presentation would be left without an image — a
    /// choice that was never a choice.
    static func convertibleTargets(from current: String) -> [String] {

        return all.filter { conversion(from: current, to: $0) == .transcode }

    }

    /// The one format every image in a drop shares, or nil when the drop settles nothing: no images
    /// at all, or more than one format among them. Non-image files are ignored, so a folder of
    /// JPEGs with their narration still reads as a JPEG batch — but a drop mixing PNGs and SVGs is
    /// not a format change, because there is no format to change to.
    static func uniformFormat(of urls: [URL]) -> String? {

        var formats: Set<String> = []

        for url in urls {

            let ext = Util.shared.canonicalImageExt(url.pathExtension)

            guard isSlideImage(ext) else { continue }

            formats.insert(ext)

        }

        return formats.count == 1 ? formats.first : nil

    }

    /// The dropped files that name a page, and so could actually be placed on a slide. Every import
    /// is keyed by the page number the file name ends in, so a file carrying no digits ("logo.svg",
    /// "cover.png") names no slide and is skipped by the import — and it must not get a say in what
    /// format a batch is either. Left in, one stray unnumbered image offered to convert an entire
    /// presentation and then imported nothing, which on an SVG deck is unrecoverable.
    static func namingAPage(_ urls: [URL]) -> [URL] {

        return urls.filter {
            !Util.shared.parseNumFromFileName(string: $0.deletingPathExtension().lastPathComponent).isEmpty
        }

    }

    /// What it takes to move one image from one format to the other.
    enum Conversion {

        /// Already there — the two spellings of JPEG land here too.
        case none

        /// Re-encode the pixels (PNG↔JPG).
        case transcode

        /// Cannot be done in the packager: nothing recovers vector artwork from a raster image, and
        /// drawing vector artwork into pixels is a job for whatever exported the deck.
        ///
        /// Rasterizing SVG here was tried and taken back out. There is no synchronous way to draw an
        /// SVG on this deployment target, so it meant an off-screen WKWebView per slide — which made
        /// the whole conversion asynchronous, and that one property is what pulled in a progress
        /// sheet, a save-deferral queue, a hand-rolled SVG measurer and its own DPI model. It also
        /// produced a different image on a Retina machine than on the build machine. An author
        /// changing format has the deck that produced the SVGs and can re-export it; the packager
        /// says which slides need it rather than guessing at the artwork.
        case impossible

    }

    static func conversion(from: String, to: String) -> Conversion {

        let source = Util.shared.canonicalImageExt(from)
        let target = Util.shared.canonicalImageExt(to)

        if source == target { return .none }
        if target == FileExtensions.SVG || source == FileExtensions.SVG { return .impossible }

        return .transcode

    }

    /// What changing a presentation's format does to the slide images it already holds.
    struct SwitchPlan {

        let from: String
        let to: String

        /// Files the incoming batch is about to write over. Converting these would be wasted work.
        let replaced: [String]

        /// Files that follow the presentation into the new format.
        let converted: [String]

        /// Files that cannot: the slides that end up with no image at all.
        let lost: [String]

        /// How many files the incoming batch will write. `replaced` counts only the ones landing on
        /// a slide that already had an image, so it can't stand in for the size of the batch.
        let incoming: Int

    }

    /// Partition the presentation's current slide images three ways. `existingAssetNames` is the raw
    /// filename list from assets/pages/, so a bundle's frames ("name-3.svg") partition alongside
    /// ordinary slides with no special case. `replacedBy` is the set of filenames the incoming batch
    /// will write; a file is matched to it by name without extension, since the batch writes the
    /// same slide under a different one.
    static func plan(from: String,
                     to: String,
                     existingAssetNames: [String],
                     replacedBy: Set<String>) -> SwitchPlan {

        let source = Util.shared.canonicalImageExt(from)
        let target = Util.shared.canonicalImageExt(to)
        let incoming = baseNames(of: replacedBy)
        let conversion = self.conversion(from: source, to: target)

        var replaced: [String] = []
        var converted: [String] = []
        var lost: [String] = []

        for name in existingAssetNames.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {

            guard Util.shared.sameImageFormat((name as NSString).pathExtension, source) else { continue }

            if incoming.contains(baseKey(name)) {
                replaced.append(name)
                continue
            }

            switch conversion {
            case .none:
                continue
            case .transcode:
                converted.append(name)
            case .impossible:
                lost.append(name)
            }

        }

        return SwitchPlan(from: source,
                          to: target,
                          replaced: replaced,
                          converted: converted,
                          lost: lost,
                          incoming: replacedBy.count)

    }

    /// How a slide is identified across a format change: its file name without the extension,
    /// case-folded because the filesystem is. Matching case-sensitively let an existing "Deck01.svg"
    /// and an incoming "deck01.jpg" both be written, as two wrapper entries for one file on disk —
    /// and the extension comparison beside this one has always folded case.
    static func baseKey(_ fileName: String) -> String {
        return (fileName as NSString).deletingPathExtension.lowercased()
    }

    static func baseNames<S: Sequence>(of fileNames: S) -> Set<String> where S.Element == String {
        return Set(fileNames.map { baseKey($0) })
    }

}
