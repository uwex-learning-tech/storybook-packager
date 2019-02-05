//
//  PreferencesViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/5/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set view size
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height)
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // update window title with active tab title
        self.parent?.view.window?.title = self.title!
    }
    
}
