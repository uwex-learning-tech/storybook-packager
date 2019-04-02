//
//  QuizViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/22/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import sbplus_xml_parser

class QuizViewController: NSViewController, NSTextViewDelegate {

    @IBOutlet var questionTxtVw: NSTextView!
    @IBOutlet weak var answerContainer: NSView!
    
    var currentDocument: Document?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        questionTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        questionTxtVw.delegate = self
        
    }
    
    func setQuestion() {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        
        switch currentPage.quiz.type {
            
            case QuizTypes.SHORT_ANSWER:
            
                guard let quiz = currentPage.quiz as? ShortAnswer else { return }
                
                if quiz.question["text"] != nil {
                    questionTxtVw.string = quiz.question["text"]!
                }
            
            case QuizTypes.FILL_IN_THE_BLANK:
                
                guard let quiz = currentPage.quiz as? FillInTheBlank else { return }
                
                if quiz.question["text"] != nil {
                    questionTxtVw.string = quiz.question["text"]!
                }
            
            case QuizTypes.MULTIPLE_CHOICE:
                
                guard let quiz = currentPage.quiz as? MultipleChoiceSingle else { return }
                
                if quiz.question["text"] != nil {
                    questionTxtVw.string = quiz.question["text"]!
                }
            
            case QuizTypes.MULTIPLE_ANSWER:
                
                guard let quiz = currentPage.quiz as? MultipleChoiceMultiple else { return }
                
                if quiz.question["text"] != nil {
                    questionTxtVw.string = quiz.question["text"]!
                }
            
            default:
                break
        }
        
        setAnswerView()
        
    }
    
    
    private func setAnswerView() {
        
        var childController: NSViewController?
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        // reset
        if childController != nil {
            childController = nil
        }
        
        for view in answerContainer.subviews {
            view.removeFromSuperview()
        }
        
        // set current quiz item
        
        let quiz = currentPage.quiz
        
        switch quiz.type {
            
        case QuizTypes.SHORT_ANSWER:
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.SHORT_ANSWER_VIEW) as! ShortAnswerViewController
            addChild(childController!)
            answerContainer.addSubview(childController!.view)
            
            (childController as! ShortAnswerViewController).currentDocument = currentDocument!
            (childController as! ShortAnswerViewController).display()
            
        case QuizTypes.FILL_IN_THE_BLANK:
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.FILL_IN_THE_BLANK_VIEW) as! FillInTheBlankViewController
            addChild(childController!)
            answerContainer.addSubview(childController!.view)
            
            (childController as! FillInTheBlankViewController).currentDocument = currentDocument!
            (childController as! FillInTheBlankViewController).display()
            
        case QuizTypes.MULTIPLE_CHOICE:
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.MULTIPLE_CHOICE_VIEW) as! MultipleChoiceViewController
            addChild(childController!)
            answerContainer.addSubview(childController!.view)
            
            (childController as! MultipleChoiceViewController).currentDocument = currentDocument!
            (childController as! MultipleChoiceViewController).display()
            
        case QuizTypes.MULTIPLE_ANSWER:
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.MULTIPLE_ANSWER_VIEW) as! MultipleAnswerViewController
            addChild(childController!)
            answerContainer.addSubview(childController!.view)
            
            (childController as! MultipleAnswerViewController).currentDocument = currentDocument!
            (childController as! MultipleAnswerViewController).display()
            
        default:
            break
        }
        
    }
    
    func textDidEndEditing(_ sender: Notification) {
        
        guard currentDocument != nil else { return }
        guard let textView = sender.object as? NSTextView else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        currentPage.quiz.question["text"] = textView.string
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
}
