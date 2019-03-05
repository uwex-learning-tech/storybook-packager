//
//  MultiDropboxView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/28/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class ImportDragDropBoxView: NSBox {

    private var originalColor:NSColor = NSColor.gridColor
    private var targetColor:NSColor = NSColor.controlColor
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        registerForDraggedTypes([NSPasteboard.PasteboardType.URL, NSPasteboard.PasteboardType.fileURL])

    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        self.fillColor = originalColor
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        self.fillColor = originalColor
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        
        self.fillColor = targetColor
        
        if checkExtension(sender) == true {
            return .copy
        } else {
            return NSDragOperation()
        }
        
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        
        guard let destinationDocument = (sender.draggingDestinationWindow?.contentViewController as? ProjectViewController)?.document,
            let pasteboard = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let paths = pasteboard as? Array<String> else { return false }
        
        ProjectViewController.importFiles(urls: paths, document: destinationDocument)
        
        return true
        
    }
    
    fileprivate func checkExtension(_ drag: NSDraggingInfo) -> Bool {
        
        guard let board = drag.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let paths = board as? Array<String>,
            let expectedExt = (drag.draggingDestinationWindow?.contentViewController as? ProjectViewController)?.expectedExt else { return false }
        
        var accepted: Bool = false
        
        for path in paths {
            
            let suffix = URL(fileURLWithPath: path).pathExtension
            
            if expectedExt.contains(suffix) {
                accepted = true;
            } else {
                return false;
            }
            
        }
        
        return accepted
        
    }
    
}
