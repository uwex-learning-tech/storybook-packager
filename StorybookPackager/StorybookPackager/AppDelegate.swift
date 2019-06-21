//
//  AppDelegate.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var preferencesController: NSWindowController?
    var startupController: NSWindowController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // install project directory in User's Document directory for default saving directory
        let projectDirectory: URL = (Util.shared.getUserDocumentDirectory().appendingPathComponent(Util.shared.getAppName(), isDirectory: true).absoluteURL)
        Util.shared.createDirectory(path: projectDirectory.path)
        
        // create preference .plist
        let prefSettings = UserDefaults.standard
        
        if prefSettings.bool(forKey: "installed") == false {
            
            prefSettings.register(defaults: [
                Preferences.ASSET_FILE_NAME: "page",
                Preferences.PAGE_TYPE: PageTypes.IMAGE_AUDIO,
                Preferences.SPLASH_IMG_FORMAT: FileExtensions.SVG,
                Preferences.PAGE_IMG_FORMAT: FileExtensions.SVG,
                Preferences.NUM_OF_SECTIONS: 1,
                Preferences.NUM_OF_PAGES: 1,
                Preferences.KALTURA_PARTNER_ID: 1660872,
                Preferences.KALTURA_FLAVOR_ID: 487081,
                Preferences.MANIFEST_URL: URL(string: "https://media.uwex.edu/app/storybook_plus_v3/sources/manifest.json") as Any,
                "installed": true
                ])
            
        }
        
        // show start panel
        showStartupPanel()
        
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        
        // show start panel
        showStartupPanel()
        return false
        
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func showStartupPanel() {
        
        guard NSApp.mainWindow == nil else { return }
        
        if !(startupController != nil) {
            
            let storyboard = NSStoryboard(name: NSStoryboard.Name(StoryboardNames.STARTUP), bundle: nil)
            
            startupController = storyboard.instantiateInitialController() as? NSWindowController
            
        }
        
        if (startupController != nil) {
            startupController!.showWindow(nil)
        }
        
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
