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

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Insert code here to initialize your application
        
        // install app directory in User > Library > Application Support
        let appDirectory = Util.shared.getUserAppSupportDirectory().appendingPathComponent(Util.shared.getAppName(), isDirectory: true)
        
        Util.shared.createDirectory(path: appDirectory.path)
        
        // install project directory in User's Document directory
        let projectDirectory: URL = (Util.shared.getUserDocumentDirectory().appendingPathComponent(Util.shared.getAppName(), isDirectory: true).absoluteURL)
        
        Util.shared.createDirectory(path: projectDirectory.path)
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    @IBAction func newPresenation(_ sender: NSMenuItem) {

        let startPanel = NSApp.keyWindow

        if ( startPanel != nil ) {
            
            if ( startPanel?.identifier?.rawValue == "startPanel" ) {
                
                startPanel?.close()
                
            }
            
        }
        
        let newPresentation = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "PresentationWindow") as! NSWindowController
        
        newPresentation.window?.windowController?.showWindow(nil)
        newPresentation.window?.makeMain()
        
    }
}

