//
//  RecentProjects.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  The recent projects list, as the welcome window can use it.
//

import Foundation

enum RecentProjects {

    /// The recents list with repeats taken out, in the order the system gave them.
    ///
    /// `NSDocumentController` can hand back the same project more than once. A recent entry is
    /// tracked by a reference to the file rather than by its path, so renaming or moving a project
    /// leaves the entry made before the rename resolving to the same file as the one made after it,
    /// and the list comes back naming that project twice. The Open Recent menu shows the repeat
    /// without complaint; the welcome window's list is built from a diffable snapshot, which treats
    /// what it is given as unique and raises an exception on a repeat. That exception was thrown
    /// while the window was still being assembled, which left it on screen with nothing in it —
    /// and no way to get rid of it short of clearing the whole recents list.
    ///
    /// Compared on the standardized *path*, not the URL: a project is a package, so its URL can
    /// arrive with a trailing slash or without, and those two are not equal as URLs though they name
    /// the same directory. Symlinks are not resolved — that would mean touching the disk for every
    /// entry, and the case this exists for is one file reached by one path. The URL kept is the one
    /// first seen, which is the most recently opened.
    static func unique(_ urls: [URL]) -> [URL] {

        var seen = Set<String>()

        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }

    }

}
