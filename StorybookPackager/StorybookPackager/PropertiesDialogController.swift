//
//  PropertiesDialogController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/10/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

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
    
    var properties: PresentationProperties = PresentationProperties()
    var completionHandler: ((PresentationProperties) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        errorLbl.isHidden = true
        generalInfo.textContainerInset = NSSize(width: 5, height: 8)
        authorProfileTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        
    }
    
    override func viewWillAppear() {
        
        let savedProperties = (NSDocumentController.shared.currentDocument as! Document).getXmlObj().setup
        
        titleTxtfld.stringValue = savedProperties.title
        subtitleTxtfld.stringValue = savedProperties.subtitle
        programCmbx.stringValue = savedProperties.program
        courseNumTxtfld.stringValue = savedProperties.course
        releaseYearTxtfld.stringValue = savedProperties.releaseYear
        lengthTxtfld.stringValue = savedProperties.length
        generalInfo.string = savedProperties.generalInfo
        authorNameCmbx.stringValue = savedProperties.authorName
        authorProfileTxtvw.isEditable = false
        
        if (!savedProperties.authorProfile.isEmpty) {
            authorProfileTxtvw.string = savedProperties.authorProfile
            authorProfileTxtvw.isEditable = true
            overrideProfileBtn.state = .on
        }
        
    }
    
    @IBAction func titleOnEndEditing(_ sender: NSTextField) {
        
        checkForTitleError(title: sender.stringValue)
        
    }
    
    @IBAction func savePropertiesDialog(_ sender: NSButton) {
        
        properties.title = titleTxtfld.stringValue
        properties.subtitle = subtitleTxtfld.stringValue
        properties.program = programCmbx.stringValue
        properties.courseNumber = courseNumTxtfld.stringValue
        properties.releaseYear = releaseYearTxtfld.stringValue
        properties.length = lengthTxtfld.stringValue
        properties.generalInfo = generalInfo.string
        properties.authorName = authorNameCmbx.stringValue
        
        if (overrideProfileBtn.state == .on) {
            properties.authorProfile = authorProfileTxtvw.string
            properties.overrideProfile = true
        }
        
        checkForTitleError(title: properties.title)
        
        properties.OK = true
        properties.CANCEL = false
        completionHandler?(properties)
        
    }
    
    @IBAction func cancelPropertiesDialog(_ sender: NSButton) {
        
        properties.OK = false
        properties.CANCEL = true
        completionHandler?(properties)
        
    }
    
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
    }
    
    private func checkForTitleError(title: String) {
        
        if title.isEmpty {
            properties.hasError = true
            errorLbl.isHidden = false
            errorLbl.stringValue = "Please enter a title for the presentation."
        } else {
            properties.hasError = false
            errorLbl.isHidden = true
            errorLbl.stringValue = ""
        }
        
    }
    
}

struct PresentationProperties {
    var title: String = ""
    var subtitle: String = ""
    var program: String = ""
    var courseNumber: String = ""
    var releaseYear: String = ""
    var length: String = ""
    var generalInfo:String = ""
    var authorName: String = ""
    var authorPicture: String = ""
    var authorProfile: String = ""
    var overrideProfile: Bool = false
    var OK: Bool = false
    var hasError: Bool = false
    var CANCEL: Bool = false
}
