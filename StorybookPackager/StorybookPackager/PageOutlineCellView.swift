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
    @IBOutlet weak var confirmTitleBtn: NSButton!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        self.backgroundStyle = .light
    }
    
}
