//
//  Document.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

var SBPLUS_XML:XMLDocument = XMLDocument()
var START_WINDOW_VISIBLE: Bool = false

class Document: NSDocument {
    
    private let assetsDirName = "assets"
    private let xmlFileName = "sbplus.xml"
    private var firstLoaded: Bool = false
    
    var docWrapper: FileWrapper?

    override class var autosavesInPlace: Bool {
        return true
    }
    
    override func makeWindowControllers() {

        // Returns the Storyboard that contains your Document window.
        if (START_WINDOW_VISIBLE) {
            
            if (NSApp.keyWindow?.identifier?.rawValue == WindowIdentifiers.start) {
                
                NSApp.keyWindow?.resignKey()
                NSApp.keyWindow?.close()
                
            }
            
            let window = NSStoryboard(name: StoryboardIdentifiers.main, bundle: nil).instantiateController(withIdentifier: WindowIdentifiers.presentation) as? NSWindowController
            self.addWindowController(window!)
            
        }

    }
    
    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        
        START_WINDOW_VISIBLE = true
        
        var fileWrappers = fileWrapper.fileWrappers
        
        if (fileWrappers?[assetsDirName] == nil) {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        
        let assetsDirWrappers = fileWrappers?[assetsDirName]?.fileWrappers
        let xmlWrapper: FileWrapper? = assetsDirWrappers?[xmlFileName]
        
        if (xmlWrapper == nil) {
            
            SBPLUS_XML = try XMLDocument(xmlString: XML.emptyString, options: [])
            
        } else {
            
            let data: Data? = xmlWrapper?.regularFileContents
            
            if let aData = data {
                SBPLUS_XML = try XMLDocument(data: aData, options: XMLNode.Options.nodePreserveCDATA)
            }
            
        }
        
        self.docWrapper = fileWrapper
        
        //self.makeWindowControllers()
        
    }
    
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        
        if (self.docWrapper == nil) {
            self.docWrapper = FileWrapper(directoryWithFileWrappers: [:])
        }
        
        let fileWrappers = self.docWrapper?.fileWrappers
        
        if (fileWrappers?[assetsDirName] == nil) {
            
            let assetsFolder = FileWrapper(directoryWithFileWrappers: [:])
            assetsFolder.preferredFilename = assetsDirName
            
            let assetsFileWrappers = assetsFolder.fileWrappers
            
            if (assetsFileWrappers?[xmlFileName] == nil) {
                
                var xmlData: Data? = SBPLUS_XML.xmlData
                
                if ((xmlData?.isEmpty)!) {
                    SBPLUS_XML = try XMLDocument(xmlString: XML.emptyString, options: [])
                    xmlData = SBPLUS_XML.xmlData
                }
                
                if let aData = xmlData {
                    assetsFolder.addRegularFile(withContents: aData, preferredFilename: xmlFileName)
                }
                
            }
            
            self.docWrapper?.addFileWrapper(assetsFolder)
            
        } else {
            
            if (fileWrappers?[assetsDirName]?.fileWrappers?[xmlFileName] == nil) {
                
                var xmlData: Data? = SBPLUS_XML.xmlData
                
                if ((xmlData?.isEmpty)!) {
                    SBPLUS_XML = try XMLDocument(xmlString: XML.emptyString, options: [])
                    xmlData = SBPLUS_XML.xmlData
                }
                
                if let aData = xmlData {
                    fileWrappers?[assetsDirName]?.addRegularFile(withContents: aData, preferredFilename: xmlFileName)
                }
                
            }
            
        }
        
        return self.docWrapper!
        
    }
    
    func showStartPanel() {
        
        if (NSApp.windows.count == 0) {
            
            let window = NSStoryboard(name: StoryboardIdentifiers.main, bundle: nil).instantiateController(withIdentifier: WindowIdentifiers.start) as? NSWindowController
            window!.showWindow(nil)
            
        }
        
    }

}

