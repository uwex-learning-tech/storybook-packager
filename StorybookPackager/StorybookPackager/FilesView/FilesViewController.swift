//
//  FilesViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/25/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class FilesViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func closeFilesDialog(_ sender: NSButton) {
        self.dismiss(self)
    }
    
}
