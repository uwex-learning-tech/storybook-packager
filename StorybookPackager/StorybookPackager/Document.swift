//
//  Document.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class Document: NSDocument {
    
    private var DOC_WRAPPER: FileWrapper?
    private var SBPLUS_XML:XMLDocument?
    private let assetsDirName = "assets"
    private let xmlFileName = "sbplus.xml"
    private var firstLoaded: Bool = false

    override class var autosavesInPlace: Bool {
        return true
    }
    
    override func makeWindowControllers() {
        
        // Returns the Storyboard that contains your Document window.
        if (START_WINDOW_VISIBLE) {
            
            if (NSApp.keyWindow?.identifier?.rawValue == WindowIdentifiers.start) {
                
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
        
        DOC_WRAPPER = fileWrapper
        
    }
    
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        
        if (DOC_WRAPPER == nil) {
            DOC_WRAPPER = FileWrapper(directoryWithFileWrappers: [:])
        }
        
        let fileWrappers = DOC_WRAPPER?.fileWrappers
        
        if (fileWrappers?[assetsDirName] == nil) {
            
            let assetsFolder = FileWrapper(directoryWithFileWrappers: [:])
            assetsFolder.preferredFilename = assetsDirName
            
            let assetsFileWrappers = assetsFolder.fileWrappers
            
            if (assetsFileWrappers?[xmlFileName] == nil) {
                
                var xmlData: Data? = SBPLUS_XML!.xmlData
                
                if ((xmlData?.isEmpty)!) {
                    SBPLUS_XML = try XMLDocument(xmlString: XML.emptyString, options: [])
                    xmlData = SBPLUS_XML!.xmlData
                }
                
                if let aData = xmlData {
                    assetsFolder.addRegularFile(withContents: aData, preferredFilename: xmlFileName)
                }
                
            }
            
            DOC_WRAPPER?.addFileWrapper(assetsFolder)
            
        } else {
            
            let xmlWrapper: FileWrapper? = fileWrappers?[assetsDirName]?.fileWrappers?[xmlFileName]
            var xmlData: Data? = self.SBPLUS_XML!.xmlData
            
            if (xmlWrapper == nil) {
                
                if ((xmlData?.isEmpty)!) {
                    self.SBPLUS_XML = try XMLDocument(xmlString: XML.emptyString, options: [])
                    xmlData = self.SBPLUS_XML!.xmlData
                }
                
            } else {
                
                fileWrappers?[assetsDirName]?.removeFileWrapper(xmlWrapper!)
                
            }
            
            if let aData = xmlData {
                fileWrappers?[assetsDirName]?.addRegularFile(withContents: aData, preferredFilename: xmlFileName)
            }
            
        }
        
        return DOC_WRAPPER!
        
    }
    
    public func setXmlDoc(xmlStr: String) {
        
        do {
            
            self.SBPLUS_XML = try XMLDocument(xmlString: xmlStr, options: [.nodePreserveAll])
            
        } catch let error as NSError {
            
            NSLog(error.localizedDescription)
            
        }
        
    }
    
    public func getXmlDoc() -> XMLDocument {
        return self.SBPLUS_XML!
    }
    
    public func getXmlFileWrapper() -> FileWrapper {
        return (self.DOC_WRAPPER?.fileWrappers?[assetsDirName]?.fileWrappers?[xmlFileName])!
    }

}

