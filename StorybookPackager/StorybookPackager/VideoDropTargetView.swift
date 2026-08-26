//
//  VideoDropTargetView.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  The container the slide preview is hosted in, doubling as the drop target for a video dropped
//  straight onto the slide being edited.
//
//  The *container* is the destination rather than an overlay laid over the player: a view sitting
//  on top of an AVPlayerView would take the drop, but it would also take every click meant for the
//  transport controls underneath it. AppKit looks for a drag destination by walking up from the
//  view under the pointer, so a preview that ignores drags (AVPlayerView) hands them here on its
//  own. The highlight that appears while a video is over the slide is a separate, click-through
//  view that only exists for the length of the drag.
//

import Cocoa

class VideoDropTargetView: NSView {

    /// Set per slide: only the video slide types accept a dropped file at all.
    var isDropEnabled: Bool = false {
        didSet { if !isDropEnabled { hideHighlight() } }
    }

    /// What the highlight says this drop will do, phrased for the slide currently on screen.
    var dropMessage: String = "Drop a video here"

    /// Called with the dropped file once the drag has finished unwinding.
    var onDrop: ((URL) -> Void)?

    private var highlight: DropHighlightView?

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        registerForDraggedTypes([.fileURL])
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {

        guard droppedVideo(sender) != nil else { return [] }

        showHighlight()

        return .copy

    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        hideHighlight()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        hideHighlight()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return droppedVideo(sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {

        guard let url = droppedVideo(sender) else { return false }

        hideHighlight()

        // Off the drag's call stack, the same way the bulk import box does it: applying the drop can
        // put a modal sheet up over the slide, and the drag session is still unwinding here.
        DispatchQueue.main.async { [weak self] in
            self?.onDrop?(url)
        }

        return true

    }

    private func droppedVideo(_ sender: NSDraggingInfo) -> URL? {

        guard isDropEnabled, onDrop != nil else { return nil }

        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]

        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                              options: options) as? [URL] else { return nil }

        return VideoDropTarget.videoURL(from: urls)

    }

    private func showHighlight() {

        guard highlight == nil else { return }

        let view = DropHighlightView(frame: bounds)

        view.message = dropMessage
        view.autoresizingMask = [.width, .height]

        addSubview(view, positioned: .above, relativeTo: nil)

        highlight = view

    }

    private func hideHighlight() {
        highlight?.removeFromSuperview()
        highlight = nil
    }

}

/// The tint and label drawn over the preview while a video is held over it. Never hit-tested, so it
/// cannot come between the pointer and the player it covers even for the length of a drag.
private class DropHighlightView: NSView {

    var message: String = ""

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {

        let accent = NSColor.controlAccentColor

        NSColor.windowBackgroundColor.withAlphaComponent(0.85).setFill()
        bounds.fill()

        let inset = bounds.insetBy(dx: 8, dy: 8)
        let border = NSBezierPath(roundedRect: inset, xRadius: 10, yRadius: 10)

        accent.withAlphaComponent(0.12).setFill()
        border.fill()

        accent.setStroke()
        border.lineWidth = 3
        border.setLineDash([9, 6], count: 2, phase: 0)
        border.stroke()

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let text = NSAttributedString(string: message, attributes: [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style
        ])

        let size = text.size()
        let origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)

        text.draw(at: origin)

    }

}

extension NSView {

    /// Takes a whole view subtree out of the drag path, so a drag over it is offered to the view it
    /// sits in instead. WKWebView accepts a dropped file by navigating to it, which would turn a
    /// video dropped on a YouTube or Vimeo preview into the preview playing that file directly and
    /// leave the slide untouched. Called by NoDropWebView for every web view in the app, and by the
    /// video player, which has no business with a dropped file either.
    func disableFileDrops() {

        // Checked rather than called blindly: this runs on every layout pass of every web view in
        // the app, and a view that has already been swept has nothing left to unregister.
        if !registeredDraggedTypes.isEmpty {
            unregisterDraggedTypes()
        }

        for subview in subviews {
            subview.disableFileDrops()
        }

    }

}
