//
//  StartupWindowController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/5/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class StartupWindowController: NSWindowController, NSWindowDelegate {
    
    static var isLoaded: Bool = false
    
    override func windowDidLoad() {
        super.windowDidLoad()
        StartupWindowController.isLoaded = true
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        
        // hide the window instead of closing
        self.window?.orderOut(sender)
        return false
        
    }
    
    override func cancelOperation(_ sender: Any?) {
        self.window?.close()
    }
    
}
