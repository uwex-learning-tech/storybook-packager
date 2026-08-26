//
//  FilesViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/25/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class FilesViewController: NSViewController {
    
    var doc: Document?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewWillAppear() {
        doc = NSDocumentController.shared.currentDocument as? Document
    }
    
    @IBAction func closeFilesDialog(_ sender: NSButton) {
        self.dismiss(self)
    }
    
}
