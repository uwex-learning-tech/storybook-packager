//
//  ShortAnswerViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/29/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class ShortAnswerViewController: NSViewController, NSTextViewDelegate {

    @IBOutlet var feedbackTxtVw: NSTextView!
    
    var currentDocument: Document?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        feedbackTxtVw.isAutomaticQuoteSubstitutionEnabled = false
        feedbackTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        feedbackTxtVw.delegate = self
        
    }
    
    func display() {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        feedbackTxtVw.string = currentPage.quiz.feedback.simple
        
    }
    
    func textDidEndEditing(_ sender: Notification) {
        
        guard currentDocument != nil else { return }
        guard let textView = sender.object as? NSTextView else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        currentPage.quiz.feedback.simple = textView.sanitize()
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
}
