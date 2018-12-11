//
//  Document.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class Document: NSDocument {
    
    private var DOC_WRAPPER: FileWrapper?
    private var SBPLUS_XML_DOC:XMLDocument?
    private let assetsDirName = "assets"
    private let xmlFileName = "sbplus.xml"

    override class var autosavesInPlace: Bool {
        return true
    }
    
    override func makeWindowControllers() {
        
        // Returns the Storyboard that contains your Document window.
        if (START_WINDOW_VISIBLE) {
            
            if (NSApp.keyWindow?.identifier?.rawValue == WindowIdentifiers.START) {
                
                NSApp.keyWindow?.close()
                
            }
            
            let window = NSStoryboard(name: StoryboardIdentifiers.main, bundle: nil).instantiateController(withIdentifier: WindowIdentifiers.PROJECT_WINDOW) as? ProjectWindowController
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
            
            self.SBPLUS_XML_DOC = self.formatXML(doc: try XMLDocument(xmlString: self.emptyXML(), options: [.nodePreserveAll]))
            
        } else {
            
            let data: Data? = xmlWrapper?.regularFileContents
            
            if let aData = data {
                SBPLUS_XML_DOC = try XMLDocument(data: aData, options: [.nodePreserveAll])
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
                
                self.SBPLUS_XML_DOC = self.formatXML(doc: try XMLDocument(xmlString: self.emptyXML(), options: [.nodePreserveAll]))
                let xmlData:Data? = SBPLUS_XML_DOC!.xmlData
                
                if let aData = xmlData {
                    assetsFolder.addRegularFile(withContents: aData, preferredFilename: xmlFileName)
                }
                
            }
            
            DOC_WRAPPER?.addFileWrapper(assetsFolder)
            
        } else {
            
            let xmlWrapper: FileWrapper? = fileWrappers?[assetsDirName]?.fileWrappers?[xmlFileName]
            
            var xmlData: Data? = self.formatXML(doc: self.SBPLUS_XML_DOC!).xmlData
            
            if (xmlWrapper == nil) {
                
                if ((xmlData?.isEmpty)!) {
                    
                    self.SBPLUS_XML_DOC = self.formatXML(doc: try XMLDocument(xmlString: self.emptyXML(), options: [.nodePreserveAll]))
                    xmlData = self.SBPLUS_XML_DOC!.xmlData
                    
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
            
            self.SBPLUS_XML_DOC = try XMLDocument(xmlString: xmlStr, options: [.nodePreserveAll])
            
        } catch let error as NSError {
            
            NSLog(error.localizedDescription)
            
        }
        
    }
    
    public func getXmlObj() -> StorybookXml {
        
        let sbParser: SbXmlParser = SbXmlParser()
        return sbParser.parse(xmlString: self.SBPLUS_XML_DOC!.xmlString)
        
    }
    
    public func getXmlFileWrapper() -> FileWrapper {
        return (self.DOC_WRAPPER?.fileWrappers?[assetsDirName]?.fileWrappers?[xmlFileName])!
    }
    
    private func emptyXML() -> String {
        
        let setup: Setup = Setup()
        var sections: Array<Section> = Array()
        var section = Section()
        let pages: Array<Page> = Array(repeating: Page(), count: 1)
        
        section.pages = pages
        sections.append(section)
        
        let SBPLUS_XML_OBJ: StorybookXml = StorybookXml(
            accent: "#0c3b6b",
            imgFormat: "svg",
            splashFormat: "svg",
            analytics: false,
            mathJax: false,
            setup: setup,
            sections: sections,
            xmlVersion: "3.0")
        
        return SBPLUS_XML_OBJ.toString()
        
    }
    
    private func formatXML(doc: XMLDocument) -> XMLDocument {
        
        do {
            
            return try XMLDocument(xmlString: doc.xmlString(options:[.nodeCompactEmptyElement, .nodePrettyPrint]), options: [.nodePreserveAll])
            
        } catch let error as NSError {
            
            NSLog(error.localizedDescription)
            
        }
        
        return doc
        
    }

}

