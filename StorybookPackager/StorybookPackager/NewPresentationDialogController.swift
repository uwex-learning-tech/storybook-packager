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
    
    @IBOutlet weak var projectNameTipLbl: NSTextField!
    @IBOutlet weak var presentationTitleTipLbl: NSTextField!
    
    var absLocation: String = Util.shared.getDefaultProjectDirectory().absoluteString
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        location.stringValue = Util.shared.getDefaultProjectDirectory().path.ns.abbreviatingWithTildeInPath
        
    }
    
    @IBAction func browseLocation(_ sender: NSButton) {
        
        let browsePanel:NSOpenPanel = NSOpenPanel()
        
        browsePanel.canChooseDirectories = true
        browsePanel.canCreateDirectories = true
        
        browsePanel.begin(completionHandler: { result in
            
            if result == NSApplication.ModalResponse.OK {
                
                guard let locationUrl = browsePanel.url else { return }
                
                let path: NSURL = NSURL(fileURLWithPath: locationUrl.path, isDirectory: true, relativeTo: Util.shared.getUserHomeDirectory())
                
                self.location.stringValue = path.path!.ns.abbreviatingWithTildeInPath
                self.absLocation = locationUrl.absoluteString
                
            }
            
        } )
        
    }
    
    @IBAction func createNewPresentation(_ sender: NSButton) {
        
        var errors: Int = 0;
        
        if (projectName.stringValue.isEmpty) {
            
            projectName.becomeFirstResponder()
            projectNameTipLbl.stringValue = "Please enter a project name."
            projectNameTipLbl.textColor = NSColor.systemRed
            
            errors += 1
            
        }
        
        if (presentationTitle.stringValue.isEmpty) {
            
            presentationTitleTipLbl.stringValue = "Please enter a presentation title."
            presentationTitleTipLbl.textColor = NSColor.systemRed
            
            errors += 1
            
        }
        
        if ( errors == 0 ) {
            
            var completionResult = CompletionResult()
            var presentationMeta = PresentationMeta()
            
            presentationMeta.projectName = projectName.stringValue
            presentationMeta.presenationTitle = presentationTitle.stringValue
            presentationMeta.program = program.stringValue
            presentationMeta.courseCode = courseCode.stringValue
            presentationMeta.releaseYear = releaseYear.stringValue
            presentationMeta.slideCount = Int(slideCount.stringValue)!
            presentationMeta.location = self.absLocation
            
            completionResult.presentationMeta = presentationMeta
            completionResult.completed = true
            
            self.completionHandler?(completionResult)
            self.dismiss(self)
            
        }
        
    }
    
    @IBAction func cancelNewPresentation(_ sender: NSButton) {
        
        let completionResult = CompletionResult()
        self.completionHandler?(completionResult)
        self.dismiss(self)
        
    }
    
}

extension String { var ns : NSString {return self as NSString} }

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

