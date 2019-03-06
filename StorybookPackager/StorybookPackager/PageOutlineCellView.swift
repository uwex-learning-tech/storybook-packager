//
//  PageOutlineCellView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/6/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class PageOutlineCellView: NSTableCellView {

    @IBOutlet weak var cellBox: NSBox!
    @IBOutlet weak var pageNumberLbl: NSTextField!
    @IBOutlet weak var pageTypeLbl: NSTextField!
    @IBOutlet weak var pageTitleLbl: NSTextField!
    
    var isSelected: Bool = false;
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if isSelected {
            selectCell()
        } else {
            deselectCell()
        }
        
    }
    
    @available(OSX 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        
        PageCell.borderColorSelected = NSColor.controlAccentColor.cgColor
        
    }
    
    func selectCell() {
        cellBox.borderColor = NSColor(cgColor: PageCell.borderColorSelected)!
    }
    
    func deselectCell() {
        cellBox.borderColor = NSColor.secondaryLabelColor
    }
    
}
