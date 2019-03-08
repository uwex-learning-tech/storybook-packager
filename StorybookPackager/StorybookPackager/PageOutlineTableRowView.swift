//
//  PageOutlineTableRowView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/7/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class PageOutlineTableRowView: NSTableRowView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if !self.isSelected {
            let selectionRect: NSRect = NSInsetRect(NSRect(x: 6, y: 1, width: self.bounds.width - 12, height: self.bounds.height - 2), 3, 3)
            let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 0, yRadius: 0)
            NSColor.darkGray.setStroke()
//            NSColor.darkGray.setFill()
//            NSColor.gridColor.setStroke()
            NSColor.gridColor.setFill()
            selectionPath.stroke()
            selectionPath.fill()
        }
        
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        //super.drawSelection(in: dirtyRect)
        
        if self.selectionHighlightStyle != NSTableView.SelectionHighlightStyle.none {

            let selectionRect: NSRect = NSInsetRect(NSRect(x: 6, y: 1, width: self.bounds.width - 12, height: self.bounds.height - 2), 3, 3)
            let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 0, yRadius: 0)
            
            NSColor(calibratedHue: NSColor(cgColor: PageCell.borderColorSelected)!.hueComponent, saturation: 1, brightness: 1, alpha: 1).setStroke()
            //NSColor(calibratedHue: NSColor(cgColor: PageCell.borderColorSelected)!.hueComponent, saturation: 1, brightness: 1, alpha: 1).setFill()
            NSColor.gridColor.setFill()
            
            selectionPath.fill()
            selectionPath.stroke()

        }
        
    }

    @available(OSX 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        
        PageCell.borderColorSelected = NSColor.controlAccentColor.cgColor
        self.needsDisplay = true
        
    }
    
}
