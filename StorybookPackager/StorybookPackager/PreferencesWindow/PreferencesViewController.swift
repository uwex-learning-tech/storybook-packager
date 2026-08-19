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
    @IBOutlet weak var autoOcrTitleCb: NSButton!
    
    // resource controls
    @IBOutlet weak var kalturaPartnerIdTxtfld: NSTextField!
    @IBOutlet weak var kalturaFlavorIdTxtfld: NSTextField!
    @IBOutlet weak var manifestUrlTxtfld: NSTextField!
    
    private let prefSettings = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prefSettings.removeObject(forKey: "programSrc")
        prefSettings.removeObject(forKey: "authorSrc")
        prefSettings.removeObject(forKey: "authorProfileRepo")
        
        // set view size
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height)
        
        // get default setting for plist
//        if prefSettings.bool(forKey: "installed") == false {
//
//            prefSettings.register(defaults: [
//                Preferences.ASSET_FILE_NAME: "page",
//                Preferences.PAGE_TYPE: PageTypes.IMAGE_AUDIO,
//                Preferences.SPLASH_IMG_FORMAT: FileExtensions.SVG,
//                Preferences.PAGE_IMG_FORMAT: FileExtensions.SVG,
//                Preferences.NUM_OF_SECTIONS: 1,
//                Preferences.NUM_OF_PAGES: 1,
//                Preferences.KALTURA_PARTNER_ID: 1660872,
//                Preferences.KALTURA_FLAVOR_ID: 487081,
//                Preferences.MANIFEST_URL: URL(string: "https://media.uwex.edu/app/storybook_plus_v3/sources/manifest.json") as Any,
//                "installed": true
//                ])
//
//        }
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // change window title to tab title
        self.parent?.view.window?.title = self.title!
        
        if self.title! == "General" {
            assetFileNameTxtfld.stringValue = prefSettings.string(forKey: Preferences.ASSET_FILE_NAME)!
            initialPageTypeDrpdwn.selectItem(at: Util.shared.getPageTypeIndex(type: prefSettings.string(forKey: Preferences.PAGE_TYPE)!, collection: initialPageTypeDrpdwn.itemTitles))
            defaultSplashImgFormatDrpdwn.selectItem(withTitle: prefSettings.string(forKey: Preferences.SPLASH_IMG_FORMAT)!)
            defaultPageImgFormatDrpdwn.selectItem(withTitle: Util.shared.canonicalImageExt(prefSettings.string(forKey: Preferences.PAGE_IMG_FORMAT)!))
            initialNumOfSectionsTxtfld.stringValue = prefSettings.string(forKey: Preferences.NUM_OF_SECTIONS)!
            initialNumOfPagesTxtfld.stringValue = prefSettings.string(forKey: Preferences.NUM_OF_PAGES)!
            autoOcrTitleCb.state = prefSettings.bool(forKey: Preferences.AUTO_OCR_TITLE) ? .on : .off
        }
        
        if self.title! == "Resources" {
            kalturaPartnerIdTxtfld.stringValue = prefSettings.string(forKey: Preferences.KALTURA_PARTNER_ID)!
            kalturaFlavorIdTxtfld.stringValue = prefSettings.string(forKey: Preferences.KALTURA_FLAVOR_ID)!
            manifestUrlTxtfld.stringValue = prefSettings.url(forKey: Preferences.MANIFEST_URL)!.absoluteString
        }
        
    }
    
    override func viewWillDisappear() {
        
        if self.title! == "General" {
            prefSettings.set(assetFileNameTxtfld.stringValue, forKey: Preferences.ASSET_FILE_NAME)
            prefSettings.set(Util.shared.formatPageTypeString(string: initialPageTypeDrpdwn.titleOfSelectedItem!), forKey: Preferences.PAGE_TYPE)
            prefSettings.set(defaultSplashImgFormatDrpdwn.titleOfSelectedItem, forKey: Preferences.SPLASH_IMG_FORMAT)
            prefSettings.set(Util.shared.canonicalImageExt(defaultPageImgFormatDrpdwn.titleOfSelectedItem!), forKey: Preferences.PAGE_IMG_FORMAT)
            
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

            prefSettings.set(autoOcrTitleCb.state == .on, forKey: Preferences.AUTO_OCR_TITLE)

        }
        
        if self.title! == "Resources" {
            prefSettings.set(kalturaPartnerIdTxtfld.stringValue, forKey: Preferences.KALTURA_PARTNER_ID)
            prefSettings.set(kalturaFlavorIdTxtfld.stringValue, forKey: Preferences.KALTURA_FLAVOR_ID)
            prefSettings.set(URL(string: manifestUrlTxtfld.stringValue), forKey: Preferences.MANIFEST_URL)
        }
        
    }
    
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
    }
    
}
