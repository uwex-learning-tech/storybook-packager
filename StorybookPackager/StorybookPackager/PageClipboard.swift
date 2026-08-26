//
//  PageClipboard.swift
//  Storybook Packager
//
//  Serializes copied sections/pages (plus the bytes of the asset files they reference) into a
//  single self-contained pasteboard payload so they can be carried — via drag-and-drop or
//  Edit > Copy/Paste — into another open presentation. The payload survives the source document
//  being closed because every referenced asset's bytes travel inside it.
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Foundation
import AppKit

extension NSPasteboard.PasteboardType {
    static let storybookPages = NSPasteboard.PasteboardType("edu.uwex.media.StorybookPackager.pages")
}

// A self-contained, copy-only payload of pages and their asset bytes.
//
// The pages themselves are carried as XML (the same StorybookXml.toString() round-trip the document
// already uses) so no NSCoding/Codable is needed on Page; the asset files are carried as raw bytes
// keyed by the destination subdirectory they belong in.
enum PageClipboard {

    // One carried asset: its destination subdirectory under assets/ (e.g. "pages", "audio",
    // "audio/quiz", "video", "html", "images"), its source name, and its bytes. When `isDir` is true
    // the bytes are a FileWrapper.serializedRepresentation of a whole directory tree (used for HTML
    // pages, which are self-contained folders) rather than a single file's contents.
    struct Asset {
        let subdir: String
        let name: String
        let bytes: Data
        let isDir: Bool

        init(subdir: String, name: String, bytes: Data, isDir: Bool = false) {
            self.subdir = subdir
            self.name = name
            self.bytes = bytes
            self.isDir = isDir
        }
    }

    struct Payload {
        let pageImgFormat: String   // the source document's page image extension
        let hasRealSections: Bool   // did the copied set include an actual SECTION row?
        let xml: Data               // UTF-8 of StorybookXml.toString() for the copied fragment
        let assets: [Asset]
    }

    private static let VERSION = 1

    static func makePlist(pageImgFormat: String, hasRealSections: Bool, xml: Data, assets: [Asset]) -> Data? {

        let assetDicts: [[String: Any]] = assets.map {
            ["subdir": $0.subdir, "name": $0.name, "bytes": $0.bytes, "isDir": $0.isDir]
        }

        let root: [String: Any] = [
            "version": VERSION,
            "pageImgFormat": pageImgFormat,
            "hasRealSections": hasRealSections,
            "xml": xml,
            "assets": assetDicts
        ]

        return try? PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)

    }

    static func parsePlist(_ data: Data) -> Payload? {

        guard let root = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else { return nil }
        guard let version = root["version"] as? Int, version == VERSION else { return nil }
        guard let pageImgFormat = root["pageImgFormat"] as? String,
              let hasRealSections = root["hasRealSections"] as? Bool,
              let xml = root["xml"] as? Data else { return nil }

        let assetsRaw = root["assets"] as? [[String: Any]] ?? []

        let assets: [Asset] = assetsRaw.compactMap { dict in
            guard let subdir = dict["subdir"] as? String,
                  let name = dict["name"] as? String,
                  let bytes = dict["bytes"] as? Data else { return nil }
            let isDir = dict["isDir"] as? Bool ?? false
            return Asset(subdir: subdir, name: name, bytes: bytes, isDir: isDir)
        }

        return Payload(pageImgFormat: pageImgFormat, hasRealSections: hasRealSections, xml: xml, assets: assets)

    }

}
