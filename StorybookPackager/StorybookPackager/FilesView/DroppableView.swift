//
//  DroppableView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/14/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class DroppableView: NSView {
    
    let expectedExt = Downloadable.allExtensions
    
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
            // Lowercased here, as Downloadable names everything: written under the extension as
            // typed, the file would be looked for under the lowercase one and never found again.
            let ext = filePath.pathExtension.lowercased()
            let fileName = "\(name!).\(ext)"
            
            // Refused rather than written: for a presentation named "index" this file's name would
            // be index.html, which is the presentation's own entry point, and replacing it is not
            // something a later save undoes.
            guard !Downloadable.isTranscript(ext) || Downloadable.canName(transcript: ext, documentName: name!) else {

                Util.shared.showAlert(
                    message: "A web transcript can't be added to a presentation named \u{201C}\(name!)\u{201D}",
                    informative: "Its transcript would have to be called \(fileName), which is the name the presentation itself uses. Rename the presentation, or use a PDF transcript instead.",
                    style: .warning
                )

                continue

            }

            // A transcript is a PDF or a web page, never both: dropping one form takes the other
            // out, or the player would find two answers to the same question.
            if Downloadable.isTranscript(ext) {

                for supersededName in Downloadable.transcriptFileNames(documentName: name!) where supersededName != fileName {

                    if destinationDocument.fileWrapperExistsInRoot(name: supersededName) {
                        destinationDocument.removeRootDirFile(file: supersededName)
                    }

                }

            }

            if destinationDocument.fileWrapperExistsInRoot(name: fileName) {
                destinationDocument.removeRootDirFile(file: fileName)
            }

            destinationDocument.addDownloadFile(name: fileName, url: filePath)
            
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
