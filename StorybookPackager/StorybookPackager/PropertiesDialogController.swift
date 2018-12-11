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
    @IBOutlet weak var generalInfoTxtfld: NSTextField!
    @IBOutlet weak var authorNameCmbx: NSComboBox!
    @IBOutlet weak var authorPicTxtfld: NSTextField!
    @IBOutlet weak var authorPicBrowseBtn: NSButton!
    @IBOutlet weak var authorPicImg: NSImageView!
    @IBOutlet weak var authorProfileTxtfld: NSTextField!
    @IBOutlet weak var overrideProfileBtn: NSButton!
    @IBOutlet weak var errorLbl: NSTextField!
    
    var properties: PresentationProperties = PresentationProperties()
    var completionHandler: ((PresentationProperties) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        errorLbl.isHidden = true
        
    }
    
    override func viewWillAppear() {
        authorNameCmbx.stringValue = "Ethan Lin"
    }
    
    @IBAction func savePropertiesDialog(_ sender: NSButton) {
        
        properties.OK = true
        
        completionHandler?(properties)
        
    }
    
    @IBAction func cancelPropertiesDialog(_ sender: NSButton) {
        
        properties.OK = false
        
        completionHandler?(properties)
        
    }
    
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
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
}
