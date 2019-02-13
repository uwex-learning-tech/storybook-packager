//
//  FileItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/13/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class FileItem: NSObject {
    
    let url: URL
    let parent: FileItem?
    let isLeaf: Bool
    static let requiredAttributes = [URLResourceKey.isDirectoryKey]
    static let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
    
    lazy var children: [FileItem]? = {
        
        if let enumerator = FileManager.default.enumerator(at: self.url, includingPropertiesForKeys: FileItem.requiredAttributes, options: FileItem.options, errorHandler: nil) {
            
            var files = [FileItem]()
            
            while let url = enumerator.nextObject() as? NSURL {
                
                do {
                    let properties = try url.resourceValues(forKeys: FileItem.requiredAttributes)
                    files.append(FileItem(url: url as URL, parent: self, isLeaf: (properties[URLResourceKey.isDirectoryKey] as! NSNumber).boolValue))
                } catch let error as NSError {
                    
                }
                
            }
            
            return files
            
        }
        
        return nil
        
    }()
    
    init(url: URL, parent: FileItem?, isLeaf: Bool) {
        self.url = url
        self.parent = parent
        self.isLeaf = isLeaf
    }
    
    var name:String {
        get {
            return self.url.lastPathComponent
        }
    }
    
    var count: Int {
        return (self.children?.count)!
    }
    
    func child(atIndex: Int) -> FileItem? {
        return self.children![atIndex]
    }
    
}
