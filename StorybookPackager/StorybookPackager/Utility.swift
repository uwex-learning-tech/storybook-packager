//
//  Utility.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 9/21/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Foundation

final class Util {
    
    static let shared: Util = Util()
    
    private init() {}
    
    func createDirectory( path: String ) {
        
        do {
            
            var isDir: ObjCBool = false
            var directoryExists = false
            
            if ( FileManager.default.fileExists(atPath: path, isDirectory: &isDir) ) {
                
                if ( isDir.boolValue ) {
                    
                    directoryExists = true
                    
                }
                
            }
            
            if ( !directoryExists ) {
                
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                
            }
            
        } catch let error as NSError {
            
            print(error.localizedFailureReason as Any)
            
        }
        
    }
    
    func getUserHomeDirectory() -> URL {
        
        return FileManager.default.homeDirectoryForCurrentUser.absoluteURL
        
    }
    
    func getUserAppSupportDirectory() -> URL {
        
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        
    }
    
    func getUserDocumentDirectory() -> URL {
        
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
    }
    
    func getDefaultProjectDirectory() -> URL {
        
        let directory = URL(fileURLWithPath: self.getUserDocumentDirectory().path, isDirectory: true, relativeTo: self.getUserHomeDirectory()).appendingPathComponent(self.getAppName())
        
        return directory.absoluteURL
        
    }
    
    func getAppName() -> String {
        
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)!
        
    }
    
    func writeToFile(path: URL, content: String) {
    
        do {
            
            try content.write(to: path, atomically: true, encoding: .utf8)
            
        } catch let error as NSError {
            
            print(error.localizedFailureReason as Any)
            
        }
        
    }
    
}
