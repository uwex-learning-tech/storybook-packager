//
//  PropertiesDialogController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/10/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class PropertiesDialogController: NSViewController {
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var subtitleTxtfld: NSTextField!
    @IBOutlet weak var programCmbx: NSComboBox!
    @IBOutlet weak var courseNumTxtfld: NSTextField!
    @IBOutlet weak var releaseYearTxtfld: NSTextField!
    @IBOutlet weak var lengthTxtfld: NSTextField!
    @IBOutlet var generalInfo: NSTextView!
    @IBOutlet weak var authorNameCmbx: NSComboBox!
    @IBOutlet weak var authorPicTxtfld: NSTextField!
    @IBOutlet weak var authorPicBrowseBtn: NSButton!
    @IBOutlet weak var authorPicImg: NSImageView!
    @IBOutlet var authorProfileTxtvw: NSTextView!
    @IBOutlet weak var overrideProfileBtn: NSButton!
    @IBOutlet weak var errorLbl: NSTextField!
    
    private var properties: Setup?
    
    var result: Result = Result()
    var completionHandler: ((Result) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        errorLbl.isHidden = true
        generalInfo.textContainerInset = NSSize(width: 5, height: 8)
        authorProfileTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        
    }
    
    override func viewWillAppear() {
        
        properties = (NSDocumentController.shared.currentDocument as! Document).getXmlObj().setup
        
        titleTxtfld.stringValue = properties!.title
        subtitleTxtfld.stringValue = properties!.subtitle
        programCmbx.stringValue = properties!.program
        courseNumTxtfld.stringValue = properties!.course
        releaseYearTxtfld.stringValue = properties!.releaseYear
        lengthTxtfld.stringValue = properties!.length
        generalInfo.string = properties!.generalInfo
        authorNameCmbx.stringValue = properties!.authorName
        authorProfileTxtvw.isEditable = false
        
        if (!properties!.authorProfile.isEmpty) {
            authorProfileTxtvw.string = properties!.authorProfile
            authorProfileTxtvw.isEditable = true
            overrideProfileBtn.state = .on
        }
        
    }
    
    @IBAction func titleOnEndEditing(_ sender: NSTextField) {
        
        checkForTitleError(title: sender.stringValue)
        
    }
    
    @IBAction func savePropertiesDialog(_ sender: NSButton) {
        
        self.view.window?.makeFirstResponder(nil)
        
        var newProperties: Setup = properties!
        var hasChange: Bool = false
        
        if (properties?.title != titleTxtfld.stringValue) {
            newProperties.title = titleTxtfld.stringValue
            hasChange = true
        }
        
        if (properties?.subtitle != subtitleTxtfld.stringValue) {
            newProperties.subtitle = subtitleTxtfld.stringValue
            hasChange = true
        }
        
        if (properties?.program != programCmbx.stringValue) {
            newProperties.program = programCmbx.stringValue
            hasChange = true
        }

        if (properties?.course != courseNumTxtfld.stringValue) {
            newProperties.course = courseNumTxtfld.stringValue
            hasChange = true
        }
        
        if (properties?.releaseYear != releaseYearTxtfld.stringValue) {
            newProperties.releaseYear = releaseYearTxtfld.stringValue
            hasChange = true
        }
        
        if (properties?.length != lengthTxtfld.stringValue) {
            newProperties.length = lengthTxtfld.stringValue
            hasChange = true
        }

        if (properties?.generalInfo != generalInfo.string) {
            newProperties.generalInfo = generalInfo.string
            hasChange = true
        }
        
        if (properties?.authorName != authorNameCmbx.stringValue) {
            newProperties.authorName = authorNameCmbx.stringValue
            hasChange = true
        }
        
        if (overrideProfileBtn.state == .on) {
            
            if (properties?.authorProfile != authorProfileTxtvw.string) {
                newProperties.authorProfile = authorProfileTxtvw.string
                hasChange = true
            }
            
            if (properties?.overrideProfile != (overrideProfileBtn.state == .on ? true : false)) {
                newProperties.overrideProfile = overrideProfileBtn.state == .on ? true : false
                hasChange = true
            }
            
        } else {
            
            newProperties.authorProfile = ""
            newProperties.overrideProfile = false
            
            if (properties?.overrideProfile != (overrideProfileBtn.state == .on ? true : false)) {
                newProperties.overrideProfile = overrideProfileBtn.state == .on ? true : false
                hasChange = true
            }
            
        }
        
        if (hasChange && !result.hasError) {
            (NSDocumentController.shared.currentDocument as! Document).getXmlObj().setSetup(setup: newProperties)
            (NSDocumentController.shared.currentDocument as! Document).updateChangeCount(NSDocument.ChangeType.changeDone)
        }
        
        result.OK = true
        result.CANCEL = false
        completionHandler?(result)
        
    }
    
    @IBAction func cancelPropertiesDialog(_ sender: NSButton) {
        
        result.OK = false
        result.CANCEL = true
        completionHandler?(result)
        
    }
    
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
    }
    
    private func checkForTitleError(title: String) {
        
        if title.isEmpty {
            result.hasError = true
            errorLbl.isHidden = false
            errorLbl.stringValue = "Please enter a title for the presentation."
        } else {
            result.hasError = false
            errorLbl.isHidden = true
            errorLbl.stringValue = ""
        }
        
    }
    
}
