//
//  FilesOutlineView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/25/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class FilesOutlineView: NSOutlineView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    
    override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {

        let superFrame = super.frameOfCell(atColumn: column, row: row)

        if row == 0 && column == 0 {
            return NSMakeRect(0, superFrame.origin.y, self.bounds.size.width, superFrame.size.height)
        }

        return superFrame

    }
    
    @IBAction func doubleClickExpand(_ sender: NSOutlineView) {
        
        let item = sender.item(atRow: sender.clickedRow)
        
        if item is FileItem {
            
            if sender.isItemExpanded(item) {
                sender.collapseItem(item)
            } else {
                sender.expandItem(item)
            }
            
        }
        
    }
    
}
