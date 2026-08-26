//
//  AppDelegate.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    lazy var welcomeWindowController = WelcomeWindowController()
    
    var documentController: DocumentController {
        return NSDocumentController.shared as! DocumentController
    }
    
    var preferencesController: NSWindowController?
    //var startupController: NSWindowController?
    
    func applicationWillFinishLaunching(_ notification: Notification) {

        _ = DocumentController()

        // Register defaults here, not in applicationDidFinishLaunching: AppKit restores document
        // windows between the two, and Document.makeWindowControllers() reads ASSET_FILE_NAME. A
        // machine that has never written the key to its persistent domain would otherwise see nil.
        // register(defaults:) populates the (non-persistent) registration domain, so it must run on
        // every launch regardless.
        UserDefaults.standard.register(defaults: [
            Preferences.ASSET_FILE_NAME: "page",
            Preferences.PAGE_TYPE: PageTypes.IMAGE_AUDIO,
            Preferences.SPLASH_IMG_FORMAT: FileExtensions.SVG,
            Preferences.PAGE_IMG_FORMAT: FileExtensions.SVG,
            Preferences.NUM_OF_SECTIONS: 1,
            Preferences.NUM_OF_PAGES: 1,
            Preferences.KALTURA_PARTNER_ID: 1660872,
            Preferences.KALTURA_FLAVOR_ID: 487081,
            Preferences.MANIFEST_URL: URL(string: "https://media.uwex.edu/app/storybook_plus_v3/sources/manifest.json") as Any,
            Preferences.AUTO_OCR_TITLE: false,
            "installed": true
            ])

    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        // install project directory in User's Document directory for default saving directory
        let projectDirectory: URL = (Util.shared.getUserDocumentDirectory().appendingPathComponent(Util.shared.getAppName(), isDirectory: true).absoluteURL)
        Util.shared.createDirectory(path: projectDirectory.path)

        if (!documentController.hasOpenedDocument) {
            welcomeWindowController.showWindow(nil)
        }
        
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        
        if (!flag) {
            welcomeWindowController.showWindow(nil)
        }
        
        return true
        
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    @IBAction func showHelp(_ sender: Any) {
        
        let alert = NSAlert()
        
        alert.messageText = #"¯\_(ツ)_/¯"#
        alert.informativeText = "(Ask Ethan)"
        alert.alertStyle = .informational
        alert.runModal()
        
    }
    
    // IB Actions
    @IBAction func showPreferences(_ sender: Any) {
        
        if !(preferencesController != nil) {
            
            let storyboard = NSStoryboard(name: NSStoryboard.Name(StoryboardNames.PREFERENCES), bundle: nil)
            
            preferencesController = storyboard.instantiateInitialController() as? NSWindowController
            
        }
        
        if (preferencesController != nil) {
            preferencesController!.showWindow(sender)
        }
        
    }
    
    @IBAction func addPageMenuItem(_ sender: Any) {
        NotificationCenter.default.post(name: Notification.Name("addNewPage"), object: NSDocumentController.shared.currentDocument!)
    }
    
    @IBAction func addSectionMenuItem(_ sender: Any) {
        NotificationCenter.default.post(name: Notification.Name("addNewSection"), object: NSDocumentController.shared.currentDocument!)
    }
    
}
