//
//  RecentProjectTableCellView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 9/17/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class RecentProjectTableCellView: NSTableCellView {

    @IBOutlet weak var recentProjTitle: NSTextFieldCell!
    @IBOutlet weak var recentProjLocation: NSTextField!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
