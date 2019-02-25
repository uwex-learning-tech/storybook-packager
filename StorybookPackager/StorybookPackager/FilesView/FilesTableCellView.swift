//
//  FilesTableCellView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/25/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class FilesTableCellView: NSTableCellView {

    @IBOutlet weak var icon: NSImageView!
    @IBOutlet weak var name: NSTextField!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
