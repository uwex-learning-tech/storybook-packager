//
//  MultiDropboxView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/28/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class MultiDropboxView: NSBox {

    private var expectedExt = ["mp3","mp4"]
    private var originalColor:NSColor = NSColor.gridColor
    private var targetColor:NSColor = NSColor.controlColor
    private var doc: Document?
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        registerForDraggedTypes([NSPasteboard.PasteboardType.URL, NSPasteboard.PasteboardType.fileURL])
        doc = NSDocumentController.shared.currentDocument as? Document
        expectedExt.append(doc!.getXmlObj().pageImgFormat)
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
        
        guard let pasteboard = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray, let paths = pasteboard as? Array<String> else { return false }
        
        let prefSettings = UserDefaults.standard
        
        NotificationCenter.default.post(name: Notification.Name("importStarted"), object: nil)
        
        for path in paths {

            let filePath = URL(fileURLWithPath: path)
            let origrinalName = filePath.deletingPathExtension().lastPathComponent
            let name = prefSettings.string(forKey: Preferences.ASSET_FILE_NAME)!
            let num = parseNum(string: origrinalName);
            let ext = filePath.pathExtension
            var directoryName = ""
            let fileName = "\(name + num).\(ext)"
            
            switch ext {
            case FileExtensions.MP3:
                directoryName = FileNames.AUDIO_DIR
            case FileExtensions.SVG, FileExtensions.JPG, FileExtensions.PNG:
                directoryName = FileNames.PAGES_DIR
            case FileExtensions.MP4:
                directoryName = FileNames.VIDEO_DIR
            default:
                directoryName = ""
            }
            
            if doc!.fileExistsInAssetsDir(fileName: fileName, subDirName: directoryName, asBool: true) as! Bool {
                
                doc!.removeFileFromAssetsDir(file: fileName, subDir: directoryName)
                doc!.addAssetsWrappersFile(name: fileName, path: filePath, to: directoryName)
                
            } else {
                
                doc!.addAssetsWrappersFile(name: fileName, path: filePath, to: directoryName)
                
            }
            
        }
        
        doc!.save(nil)
        NotificationCenter.default.post(name: Notification.Name("importCompleted"), object: nil)
        
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
    
    fileprivate func parseNum(string: String) -> String {
        
        var num = string
        
        if let regex = try? NSRegularExpression(pattern: "([0-9]*-?[0-9])$", options: NSRegularExpression.Options.caseInsensitive) {
            let matched = regex.matches(in: string, range: NSRange(location: 0, length:  string.count))
            num = matched.map{ String(string[Range($0.range, in: string)!]) }.joined()
        }
        
        let numArray = num.split(separator: "-")
        
        if numArray[0].count == 1 {
            num = "0" + num
        }
        
        return num
        
    }
    
}
