//
//  AlertList.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  The scrolling list an NSAlert shows as its accessory view. Two prompts need one — the media
//  conflicts a drop raises, and the images a slide image format change would leave behind — and it
//  lived in the first of them until the second started reaching across for it. A change to how the
//  conflict rows are laid out should not silently reshape a different alert.
//

import Cocoa

enum AlertList {

    // A scroll view shows whatever sits at its document view's origin, and an ordinary NSView puts
    // that origin at the bottom left — so a long list would open scrolled to the last row rather
    // than the first, hiding the rows the reader is most likely to be looking for.
    private final class FlippedView: NSView {
        override var isFlipped: Bool { return true }
    }

    /// A plain list of names, in the order given.
    static func accessoryView(for names: Array<String>) -> NSView {
        return accessoryView(for: names.map { NSTextField(labelWithString: $0) })
    }

    static func accessoryView(for rows: Array<NSView>) -> NSView {

        let stack = NSStackView(views: rows)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let width: CGFloat = 460
        let contentHeight = stack.fittingSize.height

        // A drop can conflict on many pages at once, and a presentation can hold hundreds of
        // slides; past a screenful the list has to scroll rather than grow the alert off the top of
        // the display.
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
