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
    private var SBPLUS_XML_PAGES: Array<Page>?
    private var _index: IndexPath = IndexPath(item: 0, section: 0)
    
    var currentPageIndex: IndexPath {
        get {
            return _index
        }
        
        set (newInt) {
            _index = newInt
        }
    }

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
            SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()
            
        } else {
            
            let data: Data? = xmlWrapper?.regularFileContents
            
            if let aData = data {
                
                SBPLUS_XML_DOC = try XMLDocument(data: aData, options: [.nodePreserveAll])
                SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
                SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()
                
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
                
                do {
                    
                    let file = try FileWrapper(url: htmlUrl, options: .withoutMapping)
                    file.preferredFilename = htmlFileName
                    
                    DOC_WRAPPER?.addFileWrapper(file)
                    
                } catch let error as NSError {
                    
                    NSLog(error.localizedDescription)
                    
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
                SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()
                
                let xmlData:Data? = SBPLUS_XML_DOC!.xmlData
                
                if let aData = xmlData {
                    assetsFolder.addRegularFile(withContents: aData, preferredFilename: xmlFileName)
                }
                
            }
            
            // create pages directory if it does not exist
            if (assetsFileWrappers?["pages"] == nil) {
                
                let folder = FileWrapper(directoryWithFileWrappers: [:])
                folder.preferredFilename = "pages"
                assetsFolder.addFileWrapper(folder)
                
            }
            
            if (assetsFileWrappers?["audio"] == nil) {
                
                let folder = FileWrapper(directoryWithFileWrappers: [:])
                folder.preferredFilename = "audio"
                assetsFolder.addFileWrapper(folder)
                
            }
            
            if (assetsFileWrappers?["video"] == nil) {
                
                let folder = FileWrapper(directoryWithFileWrappers: [:])
                folder.preferredFilename = "video"
                assetsFolder.addFileWrapper(folder)
                
            }
            
            if (assetsFileWrappers?["html"] == nil) {
                
                let folder = FileWrapper(directoryWithFileWrappers: [:])
                folder.preferredFilename = "html"
                assetsFolder.addFileWrapper(folder)
                
            }
            
            if (assetsFileWrappers?["images"] == nil) {
                
                let folder = FileWrapper(directoryWithFileWrappers: [:])
                folder.preferredFilename = "images"
                assetsFolder.addFileWrapper(folder)
                
            }
            
            DOC_WRAPPER?.addFileWrapper(assetsFolder)
        
        } else { // if asset directory does exist
            
            // get the xml file
            let xmlWrapper: FileWrapper? = fileWrappers?[assetsDirName]?.fileWrappers?[xmlFileName]
            
            if let pages: Array<Page> = SBPLUS_XML_PAGES {
                SBPLUS_XML_OBJ!.sections = SBPLUS_XML_OBJ!.backToSectionsPages(pages: pages)
            }
            
            SBPLUS_XML_DOC = formatXML(doc: (try SBPLUS_XML_OBJ?.toXMLDoc())!)
            
            var xmlData: Data? = SBPLUS_XML_DOC!.xmlData
            
            // if the xml file is empty, create a starter xml file
            if (xmlWrapper == nil) {
                
                if ((xmlData?.isEmpty)!) {
                    
                    SBPLUS_XML_DOC = formatXML(doc: try XMLDocument(xmlString: emptyXML(), options: [.nodePreserveAll]))
                    SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
                    SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()
                    
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
    
    // public functions
    
    public func getXmlObj() -> StorybookXml {
        return SBPLUS_XML_OBJ!
    }
    
    public func getXmlObjPages() -> Array<Page> {
        return SBPLUS_XML_PAGES!
    }
    
    public func addSbPage(page: Page) {
        
        page.number = self.getLastPageNumber() + 1
        page.id = "sb-pg-\(page.number)"
        page.index.section = self.getLastSectionNumber()
        
        self.SBPLUS_XML_PAGES!.append(page)
        self.updateChangeCount(.changeDone)
    }
    
    public func addSbSection(section: Page) {
        
        section.number = self.getLastSectionNumber() + 1
        section.id = "sb-sctn-\(section.number)"
        
        self.SBPLUS_XML_PAGES!.append(section)
        self.updateChangeCount(.changeDone)
    }
    
    public func getXmlFileWrapper() -> FileWrapper {
        return (self.DOC_WRAPPER?.fileWrappers?[assetsDirName]?.fileWrappers?[xmlFileName])!
    }
    
    public func addAssetFile(name: String, path: URL, to: String) {
        
        let fileWrappers = DOC_WRAPPER?.fileWrappers
        
        // if assets folder exists
        if (fileWrappers?[assetsDirName] != nil) {
            
            // get the assets folder
            let assetsFileWrappers = fileWrappers?[assetsDirName]?.fileWrappers
            let toFolderWrappers = assetsFileWrappers?[to]?.fileWrappers
            
            // create the file if it does not exist
            if (toFolderWrappers?[name] == nil) {
                
                do {
                    
                    let file = try FileWrapper(url: path, options: .withoutMapping)
                    file.preferredFilename = name
                    
                    fileWrappers?[assetsDirName]?.fileWrappers![to]!.addFileWrapper(file)
                    
                } catch let error as NSError {
                    
                    NSLog(error.localizedDescription)
                    
                }
                
            } else {
                
                fileWrappers?[assetsDirName]?.fileWrappers![to]!.removeFileWrapper((toFolderWrappers?[name])!)
                
                do {
                    
                    let file = try FileWrapper(url: path, options: .withoutMapping)
                    file.preferredFilename = name
                    
                    fileWrappers?[assetsDirName]?.fileWrappers![to]!.addFileWrapper(file)
                    
                } catch let error as NSError {
                    
                    NSLog(error.localizedDescription)
                    
                }
                
            }
            
        } // end assets folder check
        
    }
    
    public func getFileWrapper(name: String, at: String) -> FileWrapper? {
        
        guard let fileWrapper = DOC_WRAPPER?.fileWrappers?[assetsDirName]?.fileWrappers?[at]?.fileWrappers![name] else {
            return nil
        }
        
        return fileWrapper
    }
    
    // private functions
    
    private func xmlToObj(doc: XMLDocument) -> StorybookXml {
        let sbParser: SbXmlParser = SbXmlParser()
        return sbParser.parse(xmlString: doc.xmlString)
    }
    
    private func emptyXML() -> String {
        
        let setup: Setup = Setup()
        var sections: Array<Section> = Array()
        let section = Section()
        
        section.title = "Section 1"
        
        let page = Page()
        page.type = "image-audio"
        page.title = "Untitled"
        
        let pages: Array<Page> = Array(repeating: page, count: 1)
        
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
    
    private func getLastPageNumber() -> Int {
        
        for page in (SBPLUS_XML_PAGES?.reversed())! {
            
            if (page.type != "section") {
                
                return page.number
                
            }
            
        }
        
        return 0
        
    }
    
    private func getLastSectionNumber() -> Int {
        
        for section in (SBPLUS_XML_PAGES?.reversed())! {
            
            if (section.type == "section") {
                
                return section.number
                
            }
            
        }
        
        return 0
        
    }

}

