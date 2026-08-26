//
//  CaptionOverlayView.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  The caption bar the editor draws over a playing slide. The player shows captions its own way;
//  this exists so the person authoring the slide can see that the cues line up with the narration
//  without leaving the app to check.
//

import Cocoa

final class CaptionOverlayView: NSView {

    fileprivate let label: NSTextField = {

        let field = NSTextField(labelWithString: "")

        field.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        field.textColor = .white
        field.alignment = .center
        field.maximumNumberOfLines = 3
        field.lineBreakMode = .byWordWrapping
        field.translatesAutoresizingMaskIntoConstraints = false

        return field

    }()

    /// Puts a caption bar across the bottom of `container`, clear of whatever sits down there — the
    /// floating audio controls on a narrated slide, the player's own controls on a video.
    @discardableResult
    static func install(in container: NSView, bottomInset: CGFloat) -> CaptionOverlayView {

        let overlay = CaptionOverlayView()

        container.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -bottomInset),
            overlay.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 1, constant: -24),
            overlay.label.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 1, constant: -44)
        ])

        return overlay

    }

    /// Puts the bar just above `anchor` — the floating audio controls on a narrated slide — so it
    /// sits under the image without a measured inset that goes stale when the layout moves.
    @discardableResult
    static func install(in container: NSView, above anchor: NSView) -> CaptionOverlayView {

        let overlay = CaptionOverlayView()

        container.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            overlay.bottomAnchor.constraint(equalTo: anchor.topAnchor, constant: -8),
            overlay.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 1, constant: -24),
            // The label needs its own limit, or it stays one long truncated line however many lines
            // it is allowed: a maximumNumberOfLines with nothing to wrap against never wraps.
            overlay.label.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 1, constant: -44)
        ])

        return overlay

    }

    override init(frame frameRect: NSRect) {

        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        layer?.cornerRadius = 4
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true

        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5)
        ])

    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Shows one cue, or nothing at all. The bar is hidden rather than emptied between cues so it
    /// doesn't sit over the slide as a dark stripe for the whole of a silent passage.
    func show(_ text: String?) {

        guard let text = text, !text.isEmpty else {
            isHidden = true
            label.stringValue = ""
            return
        }

        label.stringValue = text
        isHidden = false

    }

}
