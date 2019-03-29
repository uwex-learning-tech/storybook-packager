//
//  MultipleAnswerViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/29/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class MultipleAnswerViewController: NSViewController, NSTextViewDelegate {

    @IBOutlet var correctFdbckTxtVw: NSTextView!
    @IBOutlet var incorrectFdbckTxtVw: NSTextView!
    
    var currentDocument: Document?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        correctFdbckTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        correctFdbckTxtVw.delegate = self
        
        incorrectFdbckTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        incorrectFdbckTxtVw.delegate = self
        
    }
    
    func display() {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        
        correctFdbckTxtVw.string = currentPage.quiz.feedback.correct
        incorrectFdbckTxtVw.string = currentPage.quiz.feedback.incorrect
        
    }
    
    func textDidEndEditing(_ sender: Notification) {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        guard let textView = sender.object as? NSTextView else { return }
        
        if textView.identifier?.rawValue == "ma_correct" {
            currentPage.quiz.feedback.correct = textView.string
        } else if textView.identifier?.rawValue == "ma_incorrect" {
            currentPage.quiz.feedback.incorrect = textView.string
        }
        
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
}
