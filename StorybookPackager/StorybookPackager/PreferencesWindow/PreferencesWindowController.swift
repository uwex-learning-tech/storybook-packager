//
//  PreferencesWindowController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/5/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        
        // hide the window instead of closing
        self.window?.orderOut(sender)
        return false
        
    }

}
