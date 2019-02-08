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
                Preferences.ASSET_FILE_NAME: "page",
                Preferences.PAGE_TYPE: PageTypes.IMAGE_AUDIO,
                Preferences.SPLASH_IMG_FORMAT: FileExtensions.SVG,
                Preferences.PAGE_IMG_FORMAT: FileExtensions.SVG,
                Preferences.NUM_OF_SECTIONS: 1,
                Preferences.NUM_OF_PAGES: 1,
                Preferences.KALTURA_PARTNER_ID: 0,
                Preferences.KALTURA_FLAVOR_ID: 0,
                Preferences.PROGRAM_SRC: URL(string: "https://media.uwex.edu/content/_programs.php") as Any,
                Preferences.AUTHOR_SRC: URL(string: "https://media.uwex.edu/content/media/storybook_support/author/_authors.php") as Any,
                Preferences.AUTHOR_REPO: URL(string: "https://media.uwex.edu/content/media/storybook_support/author/") as Any,
                "installed": true
                ])
            
        }
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // change window title to tab title
        self.parent?.view.window?.title = self.title!
        
        if self.title! == "General" {
            assetFileNameTxtfld.stringValue = prefSettings.string(forKey: Preferences.ASSET_FILE_NAME)!
            initialPageTypeDrpdwn.selectItem(at: Util.shared.getPageTypeIndex(type: prefSettings.string(forKey: Preferences.PAGE_TYPE)!, collection: initialPageTypeDrpdwn.itemTitles))
            defaultSplashImgFormatDrpdwn.selectItem(withTitle: prefSettings.string(forKey: Preferences.SPLASH_IMG_FORMAT)!)
            defaultPageImgFormatDrpdwn.selectItem(withTitle: prefSettings.string(forKey: Preferences.PAGE_IMG_FORMAT)!)
            initialNumOfSectionsTxtfld.stringValue = prefSettings.string(forKey: Preferences.NUM_OF_SECTIONS)!
            initialNumOfPagesTxtfld.stringValue = prefSettings.string(forKey: Preferences.NUM_OF_PAGES)!
        }
        
        if self.title! == "Resources" {
            kalturaPartnerIdTxtfld.stringValue = prefSettings.string(forKey: Preferences.KALTURA_PARTNER_ID)!
            kalturaFlavorIdTxtfld.stringValue = prefSettings.string(forKey: Preferences.KALTURA_FLAVOR_ID)!
            programSrcTxtfld.stringValue = prefSettings.url(forKey: Preferences.PROGRAM_SRC)!.absoluteString
            authorSrcTxtfld.stringValue = prefSettings.url(forKey: Preferences.AUTHOR_SRC)!.absoluteString
            authorProfileRepoTxtfld.stringValue = prefSettings.url(forKey: Preferences.AUTHOR_REPO)!.absoluteString
        }
        
    }
    
    override func viewWillDisappear() {
        
        if self.title! == "General" {
            prefSettings.set(assetFileNameTxtfld.stringValue, forKey: Preferences.ASSET_FILE_NAME)
            prefSettings.set(Util.shared.formatPageTypeString(string: initialPageTypeDrpdwn.titleOfSelectedItem!), forKey: Preferences.PAGE_TYPE)
            prefSettings.set(defaultSplashImgFormatDrpdwn.titleOfSelectedItem, forKey: Preferences.SPLASH_IMG_FORMAT)
            prefSettings.set(defaultPageImgFormatDrpdwn.titleOfSelectedItem, forKey: Preferences.PAGE_IMG_FORMAT)
            
            if initialNumOfSectionsTxtfld.intValue <= 0 {
                prefSettings.set(1, forKey: Preferences.NUM_OF_SECTIONS)
            } else {
                prefSettings.set(initialNumOfSectionsTxtfld.intValue, forKey: Preferences.NUM_OF_SECTIONS)
            }
            
            if initialNumOfPagesTxtfld.intValue <= 0 {
                prefSettings.set(1, forKey: Preferences.NUM_OF_PAGES)
            } else {
                prefSettings.set(initialNumOfPagesTxtfld.intValue, forKey: Preferences.NUM_OF_PAGES)
            }
            
        }
        
        if self.title! == "Resources" {
            prefSettings.set(kalturaPartnerIdTxtfld.stringValue, forKey: Preferences.KALTURA_PARTNER_ID)
            prefSettings.set(kalturaFlavorIdTxtfld.stringValue, forKey: Preferences.KALTURA_FLAVOR_ID)
            prefSettings.set(URL(string: programSrcTxtfld.stringValue), forKey: Preferences.PROGRAM_SRC)
            prefSettings.set(URL(string: authorSrcTxtfld.stringValue), forKey: Preferences.AUTHOR_SRC)
            prefSettings.set(URL(string: authorProfileRepoTxtfld.stringValue), forKey: Preferences.AUTHOR_REPO)
        }
        
    }
    
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
    }
    
}
