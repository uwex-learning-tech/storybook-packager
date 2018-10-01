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
    
    func getRecentProjectsJsonFile() -> URL {
        
        let file = self.getUserAppSupportDirectory().appendingPathComponent(Util.shared.getAppName(), isDirectory: true).appendingPathComponent(FileIdentifiers.recentProject).appendingPathExtension(FileTypeIndentifiers.json)
        
        return file.absoluteURL
        
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
    
    func read(path:URL) -> String {
        
        do {
            
            return try String(contentsOf: path)
            
        } catch let error as NSError {
            
            print(error.localizedFailureReason as Any)
            
        }
        
        return ""
        
    }
    
    func encodeRecentProjects(obj: Array<URL>) -> String {
        
        do {
            
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(obj)
            
            return String(data: jsonData, encoding: String.Encoding.utf8)!
            
        } catch let error as NSError {
            
            print(error.localizedFailureReason as Any)
            
        }
        
        return ""
        
    }
    
    func decodeRecentProjects(json: String) -> Array<URL> {
        
        do {
            
            let jsonDecoder = JSONDecoder()
            return try jsonDecoder.decode(Array<URL>.self, from: json.data(using: .utf8)!)
            
        } catch let error as NSError {
            
            print(error.localizedFailureReason as Any)
            
        }
        
        return Array<URL>()
        
    }
    
}
