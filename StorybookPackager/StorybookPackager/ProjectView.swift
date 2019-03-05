//
//  ProjectView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/5/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class ProjectView: NSView {

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        registerForDraggedTypes([NSPasteboard.PasteboardType.URL, NSPasteboard.PasteboardType.fileURL])
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        
        guard let dragAndDropView = (sender.draggingDestinationWindow?.contentViewController as? ProjectViewController)?.dragAndDropView else { return NSDragOperation() }
        
        dragAndDropView.isHidden = false
        
        return .private
        
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        guard let dragAndDropView = (sender.draggingDestinationWindow?.contentViewController as? ProjectViewController)?.dragAndDropView else { return }
        
        dragAndDropView.isHidden = true
    }
    
//    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
//
//        guard let _ = (sender.draggingDestinationWindow?.contentViewController as? ProjectViewController)?.dragAndDropView else { return false }
//
//        return true
//
//    }
    
}
