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
        
        // show start panel
        showStartupPanel()
        
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        
        // show start panel
        showStartupPanel()
        return false
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func showStartupPanel() {
        
        guard NSApp.windows.count <= 1 else { return }
        
        if !(startupController != nil) {
            
            let storyboard = NSStoryboard(name: NSStoryboard.Name(StoryboardNames.STARTUP), bundle: nil)
            
            startupController = storyboard.instantiateInitialController() as? NSWindowController
            
        }
        
        if (startupController != nil) {
            startupController!.showWindow(nil)
        }
        
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
    
}
