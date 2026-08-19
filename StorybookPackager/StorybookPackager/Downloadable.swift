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

        return transcriptExtensions.first {
            held.contains(fileName(documentName: documentName, ext: $0).lowercased())
        }

    }

    /// The transcripts that have to go when this one is set: the other forms, whichever they are.
    /// Setting a web transcript over a PDF replaces it rather than leaving two behind.
    static func supersededTranscripts(bySetting ext: String) -> [String] {

        guard isTranscript(ext) else { return [] }

        return transcriptExtensions.filter { $0 != ext.lowercased() }

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
