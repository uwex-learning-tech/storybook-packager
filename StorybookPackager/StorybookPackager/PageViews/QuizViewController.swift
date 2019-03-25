//
//  QuizViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/22/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class QuizViewController: NSViewController {

    @IBOutlet var questionTxtVw: NSTextView!
    @IBOutlet weak var answerContainer: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        questionTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        
    }
    
}
