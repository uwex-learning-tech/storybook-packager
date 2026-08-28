//
//  PageAssets.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  Which files a slide of a given type occupies, in one place.
//
//  A slide has no per-slot record of what it holds: every file it owns is built by concatenation
//  from one base name, `Page.src`. That construction used to be written out separately in the paste
//  path, the save-time snapshot, the save-time rename and the editor — four copies that drifted
//  apart, which is how a slide came to read and overwrite its neighbour's files. Everything that
//  needs to know what a slide occupies asks here instead.
//
//  Nothing in here touches the document or the file wrappers: given a type, a base name and the
//  presentation's image format, it is the list of names, and nothing else.
//

import Foundation

enum PageAssets {

    /// One file a slide occupies: a name, and the directory under assets/ it lives in.
    struct Slot: Equatable {

        let subdir: String
        let name: String

    }

    /// The files a slide of `type` occupies under `base`. Empty for the types that carry no files of
    /// their own — sections, quizzes, HTML widgets, and the streaming slides whose `src` is a video
    /// ID rather than a base name.
    ///
    /// `imageFormat` is the presentation's `pageImgFormat` **verbatim**, not canonicalised: every
    /// path that builds a slide image's name reads it raw, so canonicalising here would name files
    /// none of them look for.
    static func slots(type: String, base: String, imageFormat: String, frameCount: Int) -> [Slot] {

        switch type {

        case PageTypes.IMAGE:

            return [Slot(subdir: FileNames.PAGES_DIR, name: base + "." + imageFormat)]

        case PageTypes.IMAGE_AUDIO:

            return [Slot(subdir: FileNames.PAGES_DIR, name: base + "." + imageFormat),
                    Slot(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.MP3),
                    Slot(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.VTT)]

        case PageTypes.BUNDLE:

            // A bundle always occupies at least one frame slot, even before it holds a frame: it is
            // the name the first image it is given will take.
            var slots: [Slot] = []

            for i in 1...max(frameCount, 1) {
                slots.append(Slot(subdir: FileNames.PAGES_DIR, name: base + "-\(i)." + imageFormat))
            }

            slots.append(Slot(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.MP3))
            slots.append(Slot(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.VTT))

            return slots

        case PageTypes.VIDEO:

            return [Slot(subdir: FileNames.VIDEO_DIR, name: base + "." + FileExtensions.MP4),
                    Slot(subdir: FileNames.VIDEO_DIR, name: base + "." + FileExtensions.VTT)]

        default:

            return []

        }

    }

    /// Whether a slide of this type files anything under its `src`. False for the types whose `src`
    /// means something else entirely — a streaming video ID, an HTML widget's directory.
    static func holdsMediaFiles(type: String) -> Bool {

        return !slots(type: type, base: "x", imageFormat: FileExtensions.JPG, frameCount: 1).isEmpty

    }

    /// Every slot any slide type could occupy under `base` — the union of the per-type lists, in
    /// order, without repeats.
    ///
    /// This is what a name is reserved against. A slide's type can change after it takes its name,
    /// without the name changing: an image slide reserved only against its own image would become an
    /// image + audio slide a moment later and want narration filed under a name its neighbour holds.
    /// Reserving the union costs an occasional "…_copy1", which the next save renumbers away.
    static func allMediaSlots(base: String, imageFormat: String, frameCount: Int) -> [Slot] {

        let types = [PageTypes.IMAGE, PageTypes.IMAGE_AUDIO, PageTypes.BUNDLE, PageTypes.VIDEO]

        var union: [Slot] = []

        for type in types {
            for slot in slots(type: type, base: base, imageFormat: imageFormat, frameCount: frameCount) {
                if !union.contains(slot) { union.append(slot) }
            }
        }

        return union

    }

}
