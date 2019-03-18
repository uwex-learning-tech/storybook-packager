//
//  SBImageVIew.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/15/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class SBImageVIew: NSImageView {
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NotificationCenter.default.post(name: Notification.Name("mouseOver"), object: self.window)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NotificationCenter.default.post(name: Notification.Name("mouseOut"), object: self.window)
    }
    
}
