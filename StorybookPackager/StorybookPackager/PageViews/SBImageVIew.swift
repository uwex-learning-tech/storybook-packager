//
//  SBImageVIew.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/15/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class SBImageVIew: NSImageView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        print("entered")
    }
    
}
