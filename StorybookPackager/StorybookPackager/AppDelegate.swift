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
        
        // install project directory in User's Document directory for default saving directory
        let projectDirectory: URL = (Util.shared.getUserDocumentDirectory().appendingPathComponent(Util.shared.getAppName(), isDirectory: true).absoluteURL)
        Util.shared.createDirectory(path: projectDirectory.path)
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
}

