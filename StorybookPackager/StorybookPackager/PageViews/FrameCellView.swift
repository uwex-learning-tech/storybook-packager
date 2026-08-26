//
//  FrameCellView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/21/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class FrameCellView: NSTableCellView {
    
    @IBOutlet weak var frameNumber: NSTextField!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
}
