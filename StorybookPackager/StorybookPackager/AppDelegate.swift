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
        
        // install an app directory in User > Library > Application Support
        let appDirectory = Util.shared.getUserAppSupportDirectory().appendingPathComponent(Util.shared.getAppName(), isDirectory: true)
        
        Util.shared.createDirectory(path: appDirectory.path)
        
        // create recent project json file if it does not exist
        let recentProjectJson = Util.shared.getRecentProjectsJsonFile()
        
        if (!FileManager.default.fileExists(atPath: recentProjectJson.path) ) {

            Util.shared.writeToFile(path: recentProjectJson, content: Util.shared.encodeRecentProjects(obj: Array<URL>()))
            
        }
        
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

