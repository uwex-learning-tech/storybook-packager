//
//  DroppableView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/14/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class DroppableView: NSView {
    
    let expectedExt = ["pdf","zip","mp3","mp4"]
    
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
        
        guard let pasteboard = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let path = pasteboard[0] as? String, let doc = NSDocumentController.shared.currentDocument as? Document
            else { return false }
        
        let filePath = URL(fileURLWithPath: path)
        let name = doc.fileURL?.deletingPathExtension().lastPathComponent
        let ext = filePath.pathExtension
        let fileName = "\(name!).\(ext)"
        
        if doc.fileWrapperExistsInRoot(name: fileName) {
            
            let alert = NSAlert()
            alert.messageText = "Do you want to replace \(fileName)?"
            alert.informativeText = "Operation cannot be undone."
            
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            let result = alert.runModal()
            
            if result == NSApplication.ModalResponse.alertFirstButtonReturn{
                doc.removeDownloadFile(file: fileName)
                doc.addDownloadFile(name: fileName, path: filePath)
                NotificationCenter.default.post(name: Notification.Name("fileDropped"), object: nil, userInfo: ["extension":ext])
                doc.save(nil)
            }
            
        } else {
            doc.addDownloadFile(name: fileName, path: filePath)
            NotificationCenter.default.post(name: Notification.Name("fileDropped"), object: nil, userInfo: ["extension":ext])
            doc.save(nil)
        }
        
        return true
        
    }
    
    fileprivate func checkExtension(_ drag: NSDraggingInfo) -> Bool {
        
        guard let board = drag.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let path = board[0] as? String
            else { return false }
        
        let suffix = URL(fileURLWithPath: path).pathExtension
        
        for ext in self.expectedExt {
            if ext.lowercased() == suffix {
                return true
            }
        }
        
        return false
        
    }
    
}
