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

    // Right-clicking a row that isn't already selected selects just that row before the context
    // menu opens, so Duplicate/Copy act on the row under the cursor (matching Finder behavior)
    // rather than on a stale selection. Right-clicking empty space leaves the selection untouched.
    override func menu(for event: NSEvent) -> NSMenu? {

        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)

        if row >= 0 && !selectedRowIndexes.contains(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }

        return super.menu(for: event)

    }

}
