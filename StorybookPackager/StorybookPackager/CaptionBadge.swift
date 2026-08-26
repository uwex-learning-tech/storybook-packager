//
//  CaptionBadge.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  The "CC" that trails a slide's type in the outline. Whether a slide is captioned is otherwise
//  invisible until you open it, which is no way to check a presentation of sixty slides before it
//  ships. Every row carries a mark in the same place — lit when the captions are there, dim when
//  they are missing, and a dash on the slide types that can't take captions at all, so a gap in the
//  column always means something.
//

import Cocoa

enum CaptionBadge {

    enum State {
        case captioned
        case missing
        case unsupported
    }

    static func state(pageType: String, hasCaptions: Bool) -> State {

        guard CaptionTrack.supportsCaptions(pageType: pageType) else { return .unsupported }

        return hasCaptions ? .captioned : .missing

    }

    /// The type label with its mark: "VIDEO  CC". Drawn as text rather than as a symbol image so it
    /// follows the window's appearance — a tinted image would keep the colour it was drawn with when
    /// the user switches to dark mode without the outline reloading.
    static func typeLabel(_ type: String, state: State, baseFont: NSFont?) -> NSAttributedString {

        let font = baseFont ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let label = NSMutableAttributedString(string: type, attributes: [.font: font])

        label.append(NSAttributedString(string: "  ", attributes: [.font: font]))
        label.append(NSAttributedString(string: mark(for: state), attributes: [
            .font: NSFont.systemFont(ofSize: font.pointSize - 1, weight: markWeight(for: state)),
            .foregroundColor: colour(for: state)
        ]))

        return label

    }

    private static func mark(for state: State) -> String {

        switch state {
        case .captioned, .missing:
            return "CC"
        case .unsupported:
            // Not "no captions" but "no such thing here", and it has to read differently at a glance
            // from a slide that is merely missing them.
            return "–"
        }

    }

    private static func markWeight(for state: State) -> NSFont.Weight {
        return state == .captioned ? .bold : .regular
    }

    private static func colour(for state: State) -> NSColor {

        switch state {
        case .captioned:
            return .labelColor
        case .missing:
            return .tertiaryLabelColor
        case .unsupported:
            return .quaternaryLabelColor
        }

    }

}
