//
//  ImportConflictPrompt.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  A slide holds one kind of media: it is a video, or an image with narration audio — never both. A
//  drop can put those in competition, either by carrying an .mp3 and an .mp4 for the same page
//  number or by landing media on a page that was already authored the other way. A Kaltura,
//  YouTube, or Vimeo slide is a video too, and a fragile one: all the page holds is the ID of a
//  video on someone else's server, and any media landing on that page overwrites the ID with an
//  asset name, with nothing left in the presentation to recover it from.
//
//  So ask first, once, with a row per page. Every row is a replacement to approve, not a side to
//  pick: it opens on keeping what the slide already holds, and replacing takes a deliberate choice.
//  The first version of this asked the other way round — one checkbox per row, its meaning spelled
//  out in a paragraph above the list — and it was read as a list of replacements to decline, so
//  clearing a box chose the very replacement it was meant to refuse.
//

import Cocoa

struct ImportConflict {

    /// What the slide already holds. A streaming slide is a video hosted elsewhere; the page holds
    /// only its ID.
    enum Existing {
        case video
        case audio
        case streaming
    }

    /// What to do with the page. `keep` imports none of the files dropped for it.
    enum Choice {
        case keep
        case video
        case audio
    }

    let pageNumber: String

    /// What the slide holds now, named for the list — empty when the drop would create the page.
    let keptName: String

    /// The dropped file for each side, and the name to show for it.
    let videoName: String
    let audioName: String
    let videoURL: URL?
    let audioURL: URL?

    let existing: Existing?

    var resolution: Choice

    /// The choices this page offers, in the order shown. The first is the default, and on any page
    /// with something to lose that default is to leave it alone.
    var options: [Choice] {

        guard existing != nil else {
            // Nothing authored to protect — the page doesn't exist yet, and one of the two files
            // dropped for it has to make it. An image with narration is far and away the common slide.
            return [.audio, .video]
        }

        return [.keep]
            + (videoURL != nil ? [Choice.video] : [])
            + (audioURL != nil ? [Choice.audio] : [])

    }

    /// How one choice reads. Each row is read on its own, so the option says what it does.
    func choiceTitle(for choice: Choice) -> String {

        switch choice {
        case .keep:
            return "Keep \(keptName)"
        case .video:
            return existing == nil ? "Use \(videoName)" : "Replace with \(videoName)"
        case .audio:
            return existing == nil ? "Use \(audioName)" : "Replace with \(audioName)"
        }

    }

    /// The one replacement this page offers, when it offers exactly one. A page carrying both an
    /// .mp3 and an .mp4 offers two, and no blanket button can decide between them for you.
    var singleReplacement: Choice? {

        let replacements = options.filter { $0 != .keep }

        guard options.contains(.keep), replacements.count == 1 else { return nil }

        return replacements.first

    }

    /// The dropped files that lose this decision and must not be imported.
    var suppressedURLs: [URL] {

        switch resolution {
        case .keep:
            return [videoURL, audioURL].compactMap { $0 }
        case .video:
            return [audioURL].compactMap { $0 }
        case .audio:
            return [videoURL].compactMap { $0 }
        }

    }

}

extension ImportConflict {

    /// What a page already holds, keyed by its 1-based position — the same key the import derives
    /// from a dropped file name.
    struct ExistingPage {
        let type: String
        let src: String
    }

    /// Find the pages a drop would take media away from, or leave holding two kinds of media at
    /// once. Pages the drop only adds to, or that lose nothing, are not conflicts.
    static func detect(droppedURLs: Array<URL>, existingPages: [Int: ExistingPage]) -> [ImportConflict] {

        var audioByPage: [Int: URL] = [:]
        var videoByPage: [Int: URL] = [:]

        for filePath in droppedURLs {

            let ext = Util.shared.canonicalImageExt(filePath.pathExtension)

            guard ext == FileExtensions.MP3 || ext == FileExtensions.MP4 else { continue }

            let parsed = Util.shared.parseNumFromFileName(string: filePath.deletingPathExtension().lastPathComponent)

            // The frame suffix of a bundle image never appears on audio or video, but strip it the
            // same way the import does so the page number is derived identically.
            guard let number = Int(parsed.split(separator: "-").first.map(String.init) ?? "") else { continue }

            // Last one wins within a side, matching how the import itself treats two files claiming
            // the same page — the conflict we are after here is between the two sides.
            if ext == FileExtensions.MP3 {
                audioByPage[number] = filePath
            } else {
                videoByPage[number] = filePath
            }

        }

        return Set(audioByPage.keys).union(videoByPage.keys).sorted().compactMap { number in

            conflict(pageNumber: number,
                     droppedAudio: audioByPage[number],
                     droppedVideo: videoByPage[number],
                     existingPage: existingPages[number])

        }

    }

    private static func conflict(pageNumber: Int,
                                 droppedAudio: URL?,
                                 droppedVideo: URL?,
                                 existingPage: ExistingPage?) -> ImportConflict? {

        // A bundle is narration plus a run of images, so a video landing on one destroys the same
        // authored work an image+audio page would lose.
        let existing: Existing?

        switch existingPage?.type {
        case PageTypes.VIDEO:
            existing = .video
        case PageTypes.IMAGE_AUDIO, PageTypes.BUNDLE:
            existing = .audio
        case PageTypes.KALTURA, PageTypes.YOUTUBE, PageTypes.VIMEO:
            existing = .streaming
        default:
            existing = nil
        }

        // What the drop would cost this page. A same-kind swap costs nothing — a dropped .mp4 over a
        // video page is an ordinary replacement — except on a streaming page, where the ID it writes
        // over cannot be recovered from the presentation.
        let loses: Bool

        switch existing {
        case .video:
            loses = droppedAudio != nil
        case .audio:
            loses = droppedVideo != nil
        case .streaming:
            loses = true
        case nil:
            loses = droppedAudio != nil && droppedVideo != nil
        }

        guard loses else { return nil }

        return ImportConflict(pageNumber: Util.shared.formatPageNum(num: pageNumber),
                              keptName: keptName(existing: existing,
                                                 type: existingPage?.type ?? "",
                                                 src: existingPage?.src ?? ""),
                              videoName: droppedVideo?.lastPathComponent ?? "",
                              audioName: droppedAudio?.lastPathComponent ?? "",
                              videoURL: droppedVideo,
                              audioURL: droppedAudio,
                              existing: existing,
                              resolution: existing == nil ? .audio : .keep)

    }

    /// What the slide holds now, short enough to sit in a menu item. A streaming slide is named by
    /// its ID because a presentation can hold several and the page number alone doesn't say which
    /// video is at stake.
    static func keptName(existing: Existing?, type: String, src: String) -> String {

        switch existing {

        case .video:
            return src + "." + FileExtensions.MP4

        case .audio:
            return src + "." + FileExtensions.MP3

        case .streaming:

            let platform: String

            switch type {
            case PageTypes.KALTURA:
                platform = "Kaltura"
            case PageTypes.YOUTUBE:
                platform = "YouTube"
            case PageTypes.VIMEO:
                platform = "Vimeo"
            default:
                platform = "streaming"
            }

            return src.isEmpty ? "\(platform) video" : "\(platform) \(src)"

        case nil:
            return ""

        }

    }

}

/// The "Replace All" / "Keep All" pair above the list. A drop can conflict on dozens of pages at
/// once — a folder of narration over a run of slides authored as video — and setting each of those
/// menus by hand is the kind of tedium that gets skipped rather than done. The buttons only move
/// rows that offer a single replacement; a page with both an .mp3 and an .mp4 dropped on it is a
/// decision, not a default, and is left where it stands.
final class ImportConflictBulkActionsView: NSStackView {

    private let rows: [(conflict: ImportConflict, popUp: NSPopUpButton)]

    init(rows: [(conflict: ImportConflict, popUp: NSPopUpButton)]) {

        self.rows = rows

        super.init(frame: .zero)

        let replace = NSButton(title: "Replace All", target: self, action: #selector(replaceAll))
        let keep = NSButton(title: "Keep All", target: self, action: #selector(keepAll))

        for button in [replace, keep] {
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        }

        orientation = .horizontal
        spacing = 8
        setViews([replace, keep], in: .leading)

        setFrameSize(fittingSize)

    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc func replaceAll() {

        for row in rows {

            guard let replacement = row.conflict.singleReplacement,
                  let index = row.conflict.options.firstIndex(of: replacement) else { continue }

            row.popUp.selectItem(at: index)

        }

    }

    @objc func keepAll() {

        for row in rows {

            guard let index = row.conflict.options.firstIndex(of: .keep) else { continue }

            row.popUp.selectItem(at: index)

        }

    }

}

enum ImportConflictPrompt {

    /// Ask which replacements to go through with. Returns the resolved conflicts, or nil if the user
    /// cancelled — in which case the caller must import nothing at all.
    static func resolve(_ conflicts: [ImportConflict]) -> [ImportConflict]? {

        guard !conflicts.isEmpty else { return conflicts }

        let alert = NSAlert()

        alert.alertStyle = .warning
        alert.messageText = conflicts.count == 1
            ? "Replace the media on 1 slide?"
            : "Replace the media on \(conflicts.count) slides?"
        alert.informativeText = "Slides are left as they are unless you choose a replacement."

        // Cancel is second so Escape picks it, and it abandons the whole import rather than
        // guessing: a wrong guess here quietly destroys authored work.
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")

        let popUps = conflicts.map { popUp(for: $0) }
        let list = accessoryView(for: zip(conflicts, popUps).map { row(for: $0, popUp: $1) })

        alert.accessoryView = accessory(list: list, actions: bulkActions(for: conflicts, popUps: popUps))

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        return zip(conflicts, popUps).map { conflict, popUp in

            var resolved = conflict
            let options = conflict.options
            let selected = popUp.indexOfSelectedItem

            resolved.resolution = options.indices.contains(selected) ? options[selected] : conflict.resolution

            return resolved

        }

    }

    /// The bulk buttons, or nil when they would have nothing to do: one page is no faster to set
    /// with a button than with its own menu, and neither is a list where every page needs a real
    /// decision.
    static func bulkActions(for conflicts: [ImportConflict], popUps: [NSPopUpButton]) -> ImportConflictBulkActionsView? {

        guard conflicts.count > 1, conflicts.contains(where: { $0.singleReplacement != nil }) else { return nil }

        return ImportConflictBulkActionsView(rows: Array(zip(conflicts, popUps)))

    }

    // NSAlert lays its accessory view out from the frame it arrives with, so the two pieces are
    // stacked by hand rather than by another stack view — the list below has already sized itself,
    // and re-arranging it under constraints here would undo that.
    private static func accessory(list: NSView, actions: NSView?) -> NSView {

        guard let actions = actions else { return list }

        let spacing: CGFloat = 8
        let width = max(list.frame.width, actions.frame.width)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: actions.frame.height + spacing + list.frame.height))

        list.setFrameOrigin(.zero)
        actions.setFrameOrigin(NSPoint(x: 0, y: list.frame.height + spacing))

        container.addSubview(list)
        container.addSubview(actions)

        return container

    }

    // One pop-up per page rather than a checkbox: a page can have both an .mp3 and an .mp4 dropped
    // on it, which is a three-way decision, and a single control for every row keeps the list
    // reading the same way whatever the page happens to be.
    static func popUp(for conflict: ImportConflict) -> NSPopUpButton {

        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
        let options = conflict.options

        popUp.addItems(withTitles: options.map { conflict.choiceTitle(for: $0) })
        popUp.selectItem(at: options.firstIndex(of: conflict.resolution) ?? 0)
        popUp.cell?.lineBreakMode = .byTruncatingMiddle
        popUp.translatesAutoresizingMaskIntoConstraints = false
        popUp.widthAnchor.constraint(lessThanOrEqualToConstant: 360).isActive = true

        return popUp

    }

    private static func row(for conflict: ImportConflict, popUp: NSPopUpButton) -> NSView {

        let label = NSTextField(labelWithString: "Page \(conflict.pageNumber)")
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = NSStackView(views: [label, popUp])

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8

        return stack

    }

    // A scroll view shows whatever sits at its document view's origin, and an ordinary NSView puts
    // that origin at the bottom left — so a long list would open scrolled to the last page rather
    // than the first, hiding the rows the user is most likely to be looking for.
    private final class FlippedView: NSView {
        override var isFlipped: Bool { return true }
    }

    // Internal rather than private so a test can check the list is built top-down.
    static func accessoryView(for rows: [NSView]) -> NSView {

        let stack = NSStackView(views: rows)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let width: CGFloat = 460
        let contentHeight = stack.fittingSize.height

        // A drop can conflict on many pages at once; past a screenful the list has to scroll rather
        // than grow the alert off the top of the display.
        guard contentHeight > 220 else {

            stack.frame = NSRect(x: 0, y: 0, width: width, height: contentHeight)
            stack.translatesAutoresizingMaskIntoConstraints = true

            return stack

        }

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: 220))

        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let documentView = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: contentHeight))
        documentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])

        scrollView.documentView = documentView

        return scrollView

    }

}
