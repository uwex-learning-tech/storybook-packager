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

    @IBOutlet weak var questionTxtVwScroller: NSScrollView!
    @IBOutlet var questionTxtVw: NSTextView!
    @IBOutlet weak var answerContainer: NSView!
    @IBOutlet weak var questionImgBox: NSBox!
    @IBOutlet weak var questionImgBtn: NSButton!
    
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
        
        let questionImgBoxWidthConstraint = NSLayoutConstraint(item: questionImgBox!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 100)
        
        let quiz = currentPage.quiz
        
        if quiz.question["text"] != nil && !quiz.question["text"]!.isEmpty {
            questionTxtVw.string = quiz.question["text"]!
        }
        
        if quiz.type == QuizTypes.FILL_IN_THE_BLANK || quiz.type == QuizTypes.SHORT_ANSWER {
            
            questionImgBox.isHidden = true
            
            view.removeConstraint(questionImgBoxWidthConstraint)
            view.addConstraint(NSLayoutConstraint(item: questionTxtVwScroller!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 640))
            
        } else {
            
            questionImgBox.isHidden = false

            view.addConstraint(questionImgBoxWidthConstraint)
            view.addConstraint(NSLayoutConstraint(item: questionTxtVwScroller!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 540))
            
            if quiz.question["image"] != nil && !quiz.question["image"]!.isEmpty {
                
                let image = currentDocument?.getAssetFileWrapper(name: quiz.question["image"]!, at: FileNames.IMAGES_DIR)
                questionImgBtn.image = NSImage(data: image!.regularFileContents!)
                
            }
            
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
