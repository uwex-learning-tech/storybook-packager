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

// The renumbering a save performs, worked out before anything is touched.
//
// Kept pure — a list of slides in, a list of moves out, file existence asked of a closure — because
// the version of this that lived inside the save path, reading and mutating the wrapper tree as it
// went, was wrong three times over: it renamed slides out of files their neighbours were still being
// renamed from, it handed a name to a slide that held nothing, and it could not tell a file a slide
// *owns* from one that merely happens to sit under its name.
enum AssetRename {

    /// What the planner needs to know about one slide.
    struct Slide: Equatable {

        let type: String
        let src: String
        let frameCount: Int

    }

    /// One slot's rename. `hasSource` is whether the slide owns a file to move; when it is false the
    /// destination is cleared instead, so a slide cannot inherit the file of whoever sat there before.
    struct Move: Equatable {

        let subdir: String
        let oldFile: String
        let newFile: String
        let hasSource: Bool

    }

    struct Plan: Equatable {

        /// The new `src` for a slide, keyed by its index in the input. A slide missing from this keeps
        /// the name it has — the types that file nothing under `src`, whose `src` means something
        /// else. Every slide that does file under `src` is named, whether or not its files are there.
        let names: [Int: String]
        let moves: [Move]

    }

    /// Work out the whole renumbering. `holdsFile` is asked only about the tree as it stands before
    /// any move is applied.
    /// - Parameter spokenFor: files in the renumbered directories that belong to something this pass
    ///   does not renumber — a widget slide's narration, a quiz's media. Keyed "subdir/name".
    ///   A slide is given a name whose slots avoid these, because the alternative is a rename writing
    ///   over one of them, or the clear-the-destination branch deleting it outright.
    static func plan(slides: [Slide],
                     prefix: String,
                     imageFormat: String,
                     spokenFor: Set<String> = [],
                     holdsFile: (PageAssets.Slot) -> Bool) -> Plan {

        var names: [Int: String] = [:]
        var moves: [Move] = []

        // A name is unusable if any slot it implies is a file something else answers for. Only the
        // types this pass renumbers are here; the rest file under names they keep for ever, in the
        // same three directories, so the two namespaces can and do collide.
        func collides(_ base: String, type: String, frameCount: Int) -> Bool {

            return PageAssets.slots(type: type, base: base, imageFormat: imageFormat, frameCount: frameCount)
                .contains { spokenFor.contains($0.subdir + "/" + $0.name) }

        }

        var count = 1

        for (index, slide) in slides.enumerated() {

            var newName = Util.shared.cleanString(str: prefix + Util.shared.formatPageNum(num: count))

            count += 1

            let oldSlots = PageAssets.slots(type: slide.type, base: slide.src, imageFormat: imageFormat, frameCount: slide.frameCount)

            // Sections, quizzes, HTML widgets and the streaming types file nothing under their src,
            // and their src means something the numbering has no business rewriting.
            guard !oldSlots.isEmpty else { continue }

            // Whether there is a file to carry forward in each slot — not whether the slide is
            // entitled to the name. Every slide gets its name: a slide whose picture is missing is a
            // broken slide, not a nameless one, and the file it is missing has to keep somewhere to
            // come back to. A slot with nothing in it still yields a move, whose job is to clear the
            // destination so this slide cannot inherit what the slide before it left there.
            //
            // Two slides carrying one base both read as owning it. They each take a copy forward
            // under their own new name, which leaves one wearing a picture that is not really its
            // own — visible, and fixable by hand. Picking a winner would blank the loser and destroy
            // the only copy. Duplicate over delete.
            let owned = oldSlots.map { !slide.src.isEmpty && holdsFile($0) }

            // Stepped aside from anything spoken for. The ordinal name is the rule, not a promise:
            // a widget's narration filed as "page02.mp3" is not this slide's to overwrite, however
            // much this slide would like to be page02.
            if collides(newName, type: slide.type, frameCount: slide.frameCount) {

                var n = 1

                while collides("\(newName)_copy\(n)", type: slide.type, frameCount: slide.frameCount) { n += 1 }

                newName = "\(newName)_copy\(n)"

            }

            names[index] = newName

            let newSlots = PageAssets.slots(type: slide.type, base: newName, imageFormat: imageFormat, frameCount: slide.frameCount)

            for (i, pair) in zip(oldSlots, newSlots).enumerated() {
                moves.append(Move(subdir: pair.0.subdir, oldFile: pair.0.name, newFile: pair.1.name, hasSource: owned[i]))
            }

        }

        return Plan(names: names, moves: moves)

    }

}
