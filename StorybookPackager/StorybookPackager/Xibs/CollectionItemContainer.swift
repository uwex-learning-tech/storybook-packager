//
//  CollectionItemContainer.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 1/4/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class CollectionItemContainer: NSView {
    
    private var _selected: Bool = false
    
    var isSelected:Bool {
        
        get {
            return self._selected
        }
        
        set {
            return self._selected = newValue
        }
        
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        self.wantsLayer = true
        
        if _selected {
            select()
        } else {
            deselect()
        }
        
    }
    
    @available(OSX 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        
        PageCell.borderColorSelected = NSColor.controlAccentColor.cgColor
        
    }
    
    func select() {
        
        self.layer?.borderWidth = PageCell.borderWidthSelected
        self.layer?.borderColor = PageCell.borderColorSelected
        
    }
    
    func deselect() {
        
        self.layer?.borderWidth = PageCell.borderWidth
        self.layer?.borderColor = PageCell.borderColor
        
    }
    
}
