//
//  CollectionItemContainer.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 1/4/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class CollectionItemContainer: NSView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        self.wantsLayer = true
        self.layer?.borderWidth = PageCell.borderWidth
        self.layer?.borderColor = PageCell.borderColor
    }
    
    @available(OSX 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        
        PageCell.borderColorSelected = NSColor.controlAccentColor.cgColor
        
    }
    
}
