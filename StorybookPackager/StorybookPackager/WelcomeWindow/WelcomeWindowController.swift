//
//  WelcomeWindowController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/3/22.
//  Copyright © 2022 University of Wisconsin Extended Campus. All rights reserved.
//

import Cocoa

class WelcomeWindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()

        window?.center()
        window?.isMovableByWindowBackground = true
        
        let splitViewController = WelcomeWindowSplitViewController()
        
        splitViewController.addSplitViewItem(NSSplitViewItem(viewController: MainWelcomeViewController()))
        splitViewController.addSplitViewItem(NSSplitViewItem(viewController: RecentsTableViewController()))
        
        contentViewController = splitViewController
        
    }
    
    convenience init() {
        self.init(windowNibName: NSNib.Name(String(describing: Self.self)))
    }
    
}
