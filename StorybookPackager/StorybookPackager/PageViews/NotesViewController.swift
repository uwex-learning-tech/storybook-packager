//
//  NotesViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/13/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class NotesViewController: NSViewController {

    @IBOutlet var notesTxtVw: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        notesTxtVw.isAutomaticQuoteSubstitutionEnabled = false
        
    }
    
}
