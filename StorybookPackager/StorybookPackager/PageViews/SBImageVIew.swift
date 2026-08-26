//
//  SBImageVIew.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/15/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
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
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if trackingAreas.isEmpty {
            let newTrackingArea = NSTrackingArea(rect: self.bounds, options: [NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeAlways], owner: self, userInfo: nil)
            self.addTrackingArea(newTrackingArea)
        }
        
    }
    
}
