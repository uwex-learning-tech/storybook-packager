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
        
        let newPresentation = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "PresentationWindow")) as! NSWindowController
        
        newPresentation.window?.windowController?.showWindow(nil)
        newPresentation.window?.makeMain()
        
    }
}

