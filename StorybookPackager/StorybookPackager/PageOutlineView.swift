//
//  PageOutlineView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/6/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class PageOutlineView: NSOutlineView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {
        let superFrame = super.frameOfCell(atColumn: column, row: row)
        return NSMakeRect(0, superFrame.origin.y, self.bounds.size.width, superFrame.size.height)
    }
    
    override func reloadData() {
        self.deselectAll(self)
        super.reloadData()
    }
    
}
