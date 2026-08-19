//
//  Downloadable.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  The files that ride along at the root of a package rather than in assets/ — the transcript and
//  the media a viewer can download. They are found by name, not by anything written in the XML:
//  each is the document's own name with its extension, so renaming the document renames them.
//
//  A transcript is a PDF or a web page. It is one or the other and never both, because the player
//  looks for the document's name with an extension and would find two answers.
//

import Foundation

enum Downloadable {

    /// The transcript slot, as the buttons that fill it name it. Not an extension: which extension a
    /// transcript ends up with is whatever was chosen for it.
    static let TRANSCRIPT = "transcript"

    /// The forms a transcript can take, best first — a PDF is what most of these have been, so it is
    /// the one offered first in a file panel.
    static let transcriptExtensions = [FileExtensions.PDF, FileExtensions.HTML]

    /// Everything that can sit at the root of a package under the document's name.
    static let allExtensions = transcriptExtensions + [FileExtensions.MP3, FileExtensions.MP4, FileExtensions.ZIP]

    static func isTranscript(_ ext: String) -> Bool {
        return transcriptExtensions.contains(ext.lowercased())
    }

    static func fileName(documentName: String, ext: String) -> String {
        return "\(documentName).\(ext.lowercased())"
    }

    /// Which form of transcript a package holds, or nil for none. A package that somehow holds both
    /// answers with the first form listed, so the app shows one state rather than flickering between
    /// two depending on which file it looked at first.
    static func transcriptExtension(inRootNames names: [String], documentName: String) -> String? {

        // Case-insensitively on both sides: document names carry capitals ("BIO-101"), and the
        // file may have been named by hand rather than by the app.
        let held = Set(names.map { $0.lowercased() })

        // Only names a transcript could actually be under. For a presentation named "index" the
        // web transcript's name is index.html, which is the player sitting at the root of every
        // package — read as a transcript, the app would offer to remove the presentation.
        return transcriptExtensions.first {
            canName(transcript: $0, documentName: documentName)
                && held.contains(fileName(documentName: documentName, ext: $0).lowercased())
        }

    }

    /// Every name a transcript for this document could be under — and no name it could not, so a
    /// caller sweeping the slot clear never reaches for the player's own file.
    static func transcriptFileNames(documentName: String) -> [String] {

        return transcriptExtensions
            .filter { canName(transcript: $0, documentName: documentName) }
            .map { fileName(documentName: documentName, ext: $0) }

    }

    /// The transcript files a package is actually holding, under the names they are actually stored
    /// under. The lookup matches case-insensitively — a file named by hand can differ from what the
    /// app would have called it — but removing one is an exact-name operation, so the caller needs
    /// the real key rather than the name the app would have chosen.
    static func transcriptRootNames(inRootNames names: [String], documentName: String) -> [String] {

        let wanted = Set(transcriptFileNames(documentName: documentName).map { $0.lowercased() })

        return names.filter { wanted.contains($0.lowercased()) }

    }

    /// Whether a transcript in this form can be named for this document at all. It cannot when the
    /// name it would take is index.html — the presentation's own entry point. That happens for a
    /// presentation named "index", and writing the transcript there replaces the player for good:
    /// the bundled index.html is only restored when the package has none, and this one would have
    /// one. Better to refuse than to hand back a package that opens the transcript instead of the
    /// presentation.
    static func canName(transcript ext: String, documentName: String) -> Bool {

        return fileName(documentName: documentName, ext: ext).lowercased() != FileNames.SB_HTML_FILE.lowercased()

    }

    /// Whether a file sitting at the root of a package is one of these at all. The player's own
    /// index.html is not: it is the presentation, and renaming it to the document's name would take
    /// the whole thing offline.
    static func isDownloadable(rootFileName: String) -> Bool {

        guard rootFileName.lowercased() != FileNames.SB_HTML_FILE.lowercased() else { return false }

        return allExtensions.contains((rootFileName as NSString).pathExtension.lowercased())

    }

}
