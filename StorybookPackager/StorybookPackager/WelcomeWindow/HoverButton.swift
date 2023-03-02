//
//  HoverButton.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/3/22.
//  Copyright © 2022 University of Wisconsin Extended Campus. All rights reserved.
//

import Cocoa

class HoverButton: NSButton {

    @IBInspectable var hoveringImage: NSImage?
    @IBInspectable var notHoveringImage: NSImage? {
        didSet {
            image = notHoveringImage
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addTrackingArea()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addTrackingArea()
    }

    private func addTrackingArea() {
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.image = hoveringImage
    }
    
    override func mouseExited(with event: NSEvent) {
        super.image = notHoveringImage
    }
    
}
