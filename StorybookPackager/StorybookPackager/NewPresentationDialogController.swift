//
//  NewPresentationDialogController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 9/13/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class NewPresentationDialogController: NSViewController {
    
    var completionHandler: ((CompletionResult) -> ())?
    
    @IBOutlet weak var presentationTitle: NSTextField!
    @IBOutlet weak var program: NSComboBox!
    @IBOutlet weak var courseNumber: NSTextField!
    @IBOutlet weak var releaseYear: NSTextField!
    @IBOutlet weak var slideCount: NSTextField!
    
    @IBOutlet weak var presentationTitleTipLbl: NSTextField!
    @IBOutlet weak var slideCountTipLbl: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
    }
    
    @IBAction func createNewPresentation(_ sender: NSButton) {
        
        var errors: Int = 0;
        
        if (presentationTitle.stringValue.isEmpty) {
            
            presentationTitle.becomeFirstResponder()
            presentationTitleTipLbl.stringValue = "Please enter a presentation title."
            presentationTitleTipLbl.textColor = NSColor.systemRed
            
            errors += 1
            
        }
        
        if (Int(slideCount.stringValue) == nil || slideCount.integerValue == 0) {
            
            slideCountTipLbl.stringValue = "Please enter an integer greater than 1."
            slideCountTipLbl.textColor = NSColor.systemRed
            errors += 1
            
        }
        
        if ( errors == 0 ) {
            
            var completionResult = CompletionResult()
            var presentationMeta = PresentationMeta()
            
            presentationMeta.presenationTitle = presentationTitle.stringValue
            presentationMeta.program = program.stringValue
            presentationMeta.courseCode = courseNumber.stringValue
            presentationMeta.releaseYear = releaseYear.stringValue
            presentationMeta.slideCount = slideCount.integerValue
            
            completionResult.presentationMeta = presentationMeta
            completionResult.completed = true
            
            self.completionHandler?(completionResult)
            
        }
        
    }
    
    @IBAction func cancelNewPresentation(_ sender: NSButton) {
        
        let completionResult = CompletionResult()
        self.completionHandler?(completionResult)
        
    }
    
}

extension String { var ns : NSString {return self as NSString} }

struct PresentationMeta {
    
    var presenationTitle: String = ""
    var program: String = ""
    var courseCode: String = ""
    var releaseYear: String = ""
    var slideCount: Int = 0
    
}

struct CompletionResult {
    var presentationMeta: PresentationMeta = PresentationMeta()
    var completed: Bool = false
}

