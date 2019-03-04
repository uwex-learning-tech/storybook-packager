//
//  DroppableView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/14/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class DroppableView: NSView {
    
    let expectedExt = [FileExtensions.PDF, FileExtensions.ZIP, FileExtensions.MP3, FileExtensions.MP4]
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        registerForDraggedTypes([NSPasteboard.PasteboardType.URL, NSPasteboard.PasteboardType.fileURL])
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        
        if checkExtension(sender) == true {
            return .copy
        } else {
            return NSDragOperation()
        }
        
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        
        guard let destinationDocument = (sender.draggingDestinationWindow?.contentViewController as? FilesViewController)?.doc,
            let pasteboard = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let paths = pasteboard as? Array<String> else { return false }
        
        for path in paths {
            
            let filePath = URL(fileURLWithPath: path)
            let name = destinationDocument.fileURL?.deletingPathExtension().lastPathComponent
            let ext = filePath.pathExtension
            let fileName = "\(name!).\(ext)"
            
            if destinationDocument.fileWrapperExistsInRoot(name: fileName) {
                
                destinationDocument.removeDownloadFile(file: fileName)
                destinationDocument.addDownloadFile(name: fileName, url: filePath)
                
            } else {
                
                destinationDocument.addDownloadFile(name: fileName, url: filePath)
                
            }
            
            NotificationCenter.default.post(name: Notification.Name("fileDropped"), object: nil, userInfo: ["extension":ext])
            
        }
        
        destinationDocument.save(nil)
        
        return true
        
    }
    
    fileprivate func checkExtension(_ drag: NSDraggingInfo) -> Bool {
        
        guard let board = drag.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let paths = board as? Array<String> else { return false }
        
        var accepted: Bool = false
        
        for path in paths {
            
            let suffix = URL(fileURLWithPath: path).pathExtension
            
            if self.expectedExt.contains(suffix) {
                accepted = true;
            } else {
                return false;
            }
            
        }
        
        return accepted
        
    }
    
}
