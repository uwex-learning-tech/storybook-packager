//
//  NotesViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/13/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class NotesViewController: NSViewController {

    @IBOutlet var notesTxtVw: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        self.view.frame = self.view.superview!.frame
    }
    
    func resizeContentSize() {
        self.view.frame = self.view.superview!.frame
    }
    
}
