//
//  PreferencesViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/5/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {
    
    // general controls
    @IBOutlet weak var assetFileNameTxtfld: NSTextField!
    @IBOutlet weak var initialPageTypeDrpdwn: NSPopUpButton!
    @IBOutlet weak var defaultSplashImgFormatDrpdwn: NSPopUpButton!
    @IBOutlet weak var defaultPageImgFormatDrpdwn: NSPopUpButton!
    @IBOutlet weak var initialNumOfSectionsTxtfld: NSTextField!
    @IBOutlet weak var initialNumOfPagesTxtfld: NSTextField!
    
    // resource controls
    @IBOutlet weak var kalturaPartnerIdTxtfld: NSTextField!
    @IBOutlet weak var kalturaFlavorIdTxtfld: NSTextField!
    @IBOutlet weak var programSrcTxtfld: NSTextField!
    @IBOutlet weak var authorSrcTxtfld: NSTextField!
    @IBOutlet weak var authorProfileRepoTxtfld: NSTextField!
    
    private let prefSettings = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set view size
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height)
        
        // get default setting for plist
        if prefSettings.bool(forKey: "installed") == false {
            
            prefSettings.register(defaults: [
                "assetFileName": "page",
                "pageType": "image-audio",
                "splashImgFormat": "svg",
                "pageImgFormat": "svg",
                "numSections": 1,
                "numPages": 1,
                "kalturaPartnerId": 0,
                "kalturaFlavorId": 0,
                "programSrc": URL(string: "https://media.uwex.edu/content/_programs.php") as Any,
                "authorSrc": URL(string: "https://media.uwex.edu/content/media/storybook_support/author/_authors.php") as Any,
                "authorProfileRepo": URL(string: "https://media.uwex.edu/content/media/storybook_support/author/") as Any,
                "installed": true
                ])
            
        }
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // change window title to tab title
        self.parent?.view.window?.title = self.title!
        
        if self.title! == "General" {
            assetFileNameTxtfld.stringValue = prefSettings.string(forKey: "assetFileName")!
            initialPageTypeDrpdwn.selectItem(at: Util.shared.getPageTypeIndex(type: prefSettings.string(forKey: "pageType")!, collection: initialPageTypeDrpdwn.itemTitles))
            defaultSplashImgFormatDrpdwn.selectItem(withTitle: prefSettings.string(forKey: "splashImgFormat")!)
            defaultPageImgFormatDrpdwn.selectItem(withTitle: prefSettings.string(forKey: "pageImgFormat")!)
            initialNumOfSectionsTxtfld.stringValue = prefSettings.string(forKey: "numSections")!
            initialPageTypeDrpdwn.stringValue = prefSettings.string(forKey: "numPages")!
        }
        
        if self.title! == "Resources" {
            kalturaPartnerIdTxtfld.stringValue = prefSettings.string(forKey: "kalturaPartnerId")!
            kalturaFlavorIdTxtfld.stringValue = prefSettings.string(forKey: "kalturaFlavorId")!
            programSrcTxtfld.stringValue = prefSettings.url(forKey: "programSrc")!.absoluteString
            authorSrcTxtfld.stringValue = prefSettings.url(forKey: "authorSrc")!.absoluteString
            authorProfileRepoTxtfld.stringValue = prefSettings.url(forKey: "authorProfileRepo")!.absoluteString
        }
        
    }
    
    override func viewWillDisappear() {
        
        if self.title! == "General" {
            prefSettings.set(assetFileNameTxtfld.stringValue, forKey: "assetFileName")
            prefSettings.set(Util.shared.formatPageTypeString(string: initialPageTypeDrpdwn.titleOfSelectedItem!), forKey: "pageType")
            prefSettings.set(defaultSplashImgFormatDrpdwn.titleOfSelectedItem, forKey: "splashImgFormat")
            prefSettings.set(defaultPageImgFormatDrpdwn.titleOfSelectedItem, forKey: "pageImgFormat")
            prefSettings.set(initialNumOfSectionsTxtfld.intValue, forKey: "numSections") 
            prefSettings.set(initialNumOfPagesTxtfld.intValue, forKey: "numPages")
            
        }
        
        if self.title! == "Resources" {
            prefSettings.set(kalturaPartnerIdTxtfld.stringValue, forKey: "kalturaPartnerId")
            prefSettings.set(kalturaFlavorIdTxtfld.stringValue, forKey: "kalturaFlavorId")
            prefSettings.set(URL(string: programSrcTxtfld.stringValue), forKey: "programSrc")
            prefSettings.set(URL(string: authorSrcTxtfld.stringValue), forKey: "authorSrc")
            prefSettings.set(URL(string: authorProfileRepoTxtfld.stringValue), forKey: "authorProfileRepo")
        }
        
    }
    
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
    }
    
}
