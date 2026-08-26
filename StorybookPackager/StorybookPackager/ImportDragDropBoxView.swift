//
//  MultiDropboxView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/28/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
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
        
        guard let destinationDocument = (sender.draggingDestinationWindow?.contentViewController as? ProjectViewController)?.currentDocument,
            let pasteboard = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let paths = pasteboard as? Array<String> else { return false }
        
        // Off the drag's call stack: the import puts a modal sheet up when a slide would end up both
        // video and audio, and the drag session is still unwinding at this point. The presentation
        // can be closed in the gap before this runs, which would leave a modal dialog up over
        // nothing — import only while its window is still open.
        DispatchQueue.main.async { [weak destinationDocument] in

            guard let document = destinationDocument, !document.windowControllers.isEmpty else { return }

            ProjectViewController.importFiles(urls: paths, document: document)

        }

        return true
        
    }
    
    fileprivate func checkExtension(_ drag: NSDraggingInfo) -> Bool {
        
        guard let board = drag.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray, let paths = board as? Array<String> else { return false }
        guard let currentDocument = (drag.draggingDestinationWindow?.contentViewController as? ProjectViewController)?.currentDocument else { return false }
        guard var expectedExt = (drag.draggingDestinationWindow?.contentViewController as? ProjectViewController)?.expectedExt else { return false }
        
        expectedExt.append(currentDocument.getXmlObj().pageImgFormat)
        
        var accepted: Bool = false
        
        for path in paths {
            
            // ".jpeg" and ".jpg" are the same format, so accept either spelling against a document
            // set to JPG; importFiles() stores it under the canonical extension.
            let suffix = Util.shared.canonicalImageExt(URL(fileURLWithPath: path).pathExtension)
            
            if expectedExt.contains(suffix) {
                accepted = true;
            } else {
                return false;
            }
            
        }
        
        return accepted
        
    }
    
}
