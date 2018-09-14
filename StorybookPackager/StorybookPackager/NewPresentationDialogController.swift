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
    
    @IBOutlet weak var projectName: NSTextField!
    @IBOutlet weak var presentationTitle: NSTextField!
    @IBOutlet weak var program: NSComboBox!
    @IBOutlet weak var courseCode: NSComboBox!
    @IBOutlet weak var releaseYear: NSTextField!
    @IBOutlet weak var slideCount: NSTextField!
    @IBOutlet weak var location: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func createNewPresentation(_ sender: NSButton) {
        
        var completionResult = CompletionResult()
        var presentationMeta = PresentationMeta()
        
        presentationMeta.projectName = projectName.stringValue
        presentationMeta.presenationTitle = presentationTitle.stringValue
        presentationMeta.program = program.stringValue
        presentationMeta.courseCode = courseCode.stringValue
        presentationMeta.releaseYear = releaseYear.stringValue
        presentationMeta.slideCount = Int(slideCount.stringValue)!
        presentationMeta.location = location.stringValue
        
        completionResult.presentationMeta = presentationMeta
        completionResult.completed = true
        
        self.completionHandler?(completionResult)
        self.dismissViewController(self)
        
    }
    
    @IBAction func cancelNewPresentation(_ sender: NSButton) {
        
        let completionResult = CompletionResult()
        self.completionHandler?(completionResult)
        self.dismissViewController(self)
        
    }
    
}

struct PresentationMeta {
    
    var projectName: String = ""
    var presenationTitle: String = ""
    var program: String = ""
    var courseCode: String = ""
    var releaseYear: String = ""
    var slideCount: Int = 0
    var location: String = ""
    
}

struct CompletionResult {
    var presentationMeta: PresentationMeta = PresentationMeta()
    var completed: Bool = false
}

