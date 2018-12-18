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
    private var SBPLUS_XML_OBJ: StorybookXml?
    private let assetsDirName = "assets"
    private let htmlFileName = "index.html"
    private let xmlFileName = "sbplus.xml"

    override class var autosavesInPlace: Bool {
        return false
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
        
        var fileWrappers = fileWrapper.fileWrappers
        
        // throw error if asset directory is not found
        if (fileWrappers?[assetsDirName] == nil) {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        
        // read XML file otherwise create blank xml and read
        let assetsDirWrappers = fileWrappers?[assetsDirName]?.fileWrappers
        let xmlWrapper: FileWrapper? = assetsDirWrappers?[xmlFileName]
        
        if (xmlWrapper == nil) {
            
            SBPLUS_XML_DOC = formatXML(doc: try XMLDocument(xmlString: self.emptyXML(), options: [.nodePreserveAll]))
            SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
            
        } else {
            
            let data: Data? = xmlWrapper?.regularFileContents
            
            if let aData = data {
                
                SBPLUS_XML_DOC = try XMLDocument(data: aData, options: [.nodePreserveAll])
                SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
                
            }
            
        }
        
        // return the file wrapper
        DOC_WRAPPER = fileWrapper
        
    }
    
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        
        NSApp.keyWindow?.makeFirstResponder(nil)
        
        // create filewrapper if emtpy
        if (DOC_WRAPPER == nil) {
            DOC_WRAPPER = FileWrapper(directoryWithFileWrappers: [:])
        }
        
        let fileWrappers = DOC_WRAPPER?.fileWrappers
        
        // create index.html file if it does not exist
        if (fileWrappers?[htmlFileName] == nil) {
            
            if let htmlUrl = Bundle.main.url(forResource: "index", withExtension: ".html") {
                
                let htmlData:Data? = try String(contentsOf: htmlUrl, encoding: String.Encoding.utf8).data(using: String.Encoding.utf8)
                
                if let aData = htmlData {
                    DOC_WRAPPER?.addRegularFile(withContents: aData, preferredFilename: htmlFileName)
                }
                
            }
            
        }
        
        // create asset directory folder if it does not exist
        if (fileWrappers?[assetsDirName] == nil) {
            
            let assetsFolder = FileWrapper(directoryWithFileWrappers: [:])
            assetsFolder.preferredFilename = assetsDirName
            
            let assetsFileWrappers = assetsFolder.fileWrappers
            
            // create xml file if it does not exist
            if (assetsFileWrappers?[xmlFileName] == nil) {
                
                SBPLUS_XML_DOC = formatXML(doc: try XMLDocument(xmlString: emptyXML(), options: [.nodePreserveAll]))
                SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
                
                let xmlData:Data? = SBPLUS_XML_DOC!.xmlData
                
                if let aData = xmlData {
                    assetsFolder.addRegularFile(withContents: aData, preferredFilename: xmlFileName)
                }
                
            }
            
            DOC_WRAPPER?.addFileWrapper(assetsFolder)
        
        } else { // if asset director does exist
            
            // get the xml file
            let xmlWrapper: FileWrapper? = fileWrappers?[assetsDirName]?.fileWrappers?[xmlFileName]
            
            SBPLUS_XML_DOC = formatXML(doc: (try SBPLUS_XML_OBJ?.toXMLDoc())!)
            
            var xmlData: Data? = SBPLUS_XML_DOC!.xmlData
            
            // if the xml file is empty, create a starter xml file
            if (xmlWrapper == nil) {
                
                if ((xmlData?.isEmpty)!) {
                    
                    SBPLUS_XML_DOC = formatXML(doc: try XMLDocument(xmlString: emptyXML(), options: [.nodePreserveAll]))
                    SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
                    
                    xmlData = SBPLUS_XML_DOC!.xmlData
                    
                }
                
            } else { // if it already exist, delete it
                
                fileWrappers?[assetsDirName]?.removeFileWrapper(xmlWrapper!)
                
            }
            
            // add/save the xml file
            if let aData = xmlData {
                fileWrappers?[assetsDirName]?.addRegularFile(withContents: aData, preferredFilename: xmlFileName)
            }
            
        } // end filewrapper in asset directory
        
        return DOC_WRAPPER!
        
    }
    
    public func getXmlObj() -> StorybookXml {
        
        return SBPLUS_XML_OBJ!
        
    }
    
    public func getXmlFileWrapper() -> FileWrapper {
        return (self.DOC_WRAPPER?.fileWrappers?[assetsDirName]?.fileWrappers?[xmlFileName])!
    }
    
    private func xmlToObj(doc: XMLDocument) -> StorybookXml {
        let sbParser: SbXmlParser = SbXmlParser()
        return sbParser.parse(xmlString: doc.xmlString)
    }
    
    private func emptyXML() -> String {
        
        let setup: Setup = Setup()
        var sections: Array<Section> = Array()
        var section = Section()
        let pages: Array<Page> = Array(repeating: Page(), count: 1)
        
        section.pages = pages
        sections.append(section)
        
        let SBPLUS_XML_OBJ: StorybookXml = StorybookXml(
            accent: "0c3b6b",
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

