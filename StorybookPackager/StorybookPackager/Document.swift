//
//  Document.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import sbplus_xml_parser

class Document: NSDocument {
    
    private var fileNamePrefix: String = ""
    private var DOC_WRAPPER: FileWrapper?
    private var SBPLUS_XML_DOC:XMLDocument?
    private var SBPLUS_XML_OBJ: StorybookXml?
    private var SBPLUS_XML_PAGES: Array<Page>?
    private var _index: IndexSet = []
    
    var currentPageIndex: IndexSet {
        get {
            return _index
        }
        
        set (newInt) {
            _index = newInt
        }
    }

    override class var autosavesInPlace: Bool {
        return false
    }
    
    override func makeWindowControllers() {
        
        guard StartupWindowController.isLoaded else { return }
        
        if (NSApp.keyWindow?.identifier?.rawValue == WindowIdentifiers.STARTUP) {
            NSApp.keyWindow?.close()
        }
        
        let window = NSStoryboard(name: StoryboardNames.MAIN, bundle: nil).instantiateController(withIdentifier: WindowIdentifiers.PROJECT_WINDOW) as? ProjectWindowController
        self.addWindowController(window!)

    }
    
    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        
        var fileWrappers = fileWrapper.fileWrappers
        
        // throw error if asset directory is not found
        if (fileWrappers?[FileNames.ASSET_DIR] == nil) {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        
        // read XML file otherwise create blank xml and read
        let assetsDirWrappers = fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers
        let xmlWrapper: FileWrapper? = assetsDirWrappers?[FileNames.XML_FILE]
        
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
        
        fileNamePrefix = UserDefaults.standard.string(forKey: Preferences.ASSET_FILE_NAME)!
        
        for page in SBPLUS_XML_PAGES! {
            
            if page.type == "image" || page.type == "image-audio" || page.type == "bundle" {
                
                if page.src.isEmpty { continue }
                
                let existing = Util.shared.parseAssetName(string: page.src)
                
                if existing == fileNamePrefix { break } else { fileNamePrefix = existing; break }
                
            } else {
                continue
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
        if (fileWrappers?[FileNames.SB_HTML_FILE] == nil) {
            
            if let htmlUrl = Bundle.main.url(forResource: "index", withExtension: FileExtensions.HTML) {
                
                do {
                    
                    let file = try FileWrapper(url: htmlUrl, options: .withoutMapping)
                    file.preferredFilename = FileNames.SB_HTML_FILE
                    
                    DOC_WRAPPER?.addFileWrapper(file)
                    
                } catch let error as NSError {
                    
                    NSLog(error.localizedDescription)
                    
                }
                
            }
            
        }
        
        // create asset directory folder if it does not exist
        if (fileWrappers?[FileNames.ASSET_DIR] == nil) {
            
            let assetsFolder = FileWrapper(directoryWithFileWrappers: [:])
            assetsFolder.preferredFilename = FileNames.ASSET_DIR
            
            let assetsFileWrappers = assetsFolder.fileWrappers
            
            // create xml file if it does not exist
            if (assetsFileWrappers?[FileNames.XML_FILE] == nil) {
                
                SBPLUS_XML_DOC = formatXML(doc: try XMLDocument(xmlString: emptyXML(), options: [.nodePreserveAll]))
                SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
                SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()
                
                let xmlData:Data? = SBPLUS_XML_DOC!.xmlData
                
                if let aData = xmlData {
                    assetsFolder.addRegularFile(withContents: aData, preferredFilename: FileNames.XML_FILE)
                }
                
            }
            
            DOC_WRAPPER?.addFileWrapper(assetsFolder)
        
        } else { // if asset directory does exist
            
            // get the xml file
            let xmlWrapper: FileWrapper? = fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.XML_FILE]
            
            if var pages: Array<Page> = SBPLUS_XML_PAGES {
                
                if numSections() == 0 {
                    
                    let firstSection: Page = Page()
                    firstSection.type = "section"
                    firstSection.number = 0
                    pages.insert(firstSection, at: 0)
                    
                }
                
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
                
                fileWrappers?[FileNames.ASSET_DIR]?.removeFileWrapper(xmlWrapper!)
                
            }
            
            // add/save the xml file
            if let aData = xmlData {
                fileWrappers?[FileNames.ASSET_DIR]?.addRegularFile(withContents: aData, preferredFilename: FileNames.XML_FILE)
            }
            
        } // end filewrapper in asset directory
        
        return DOC_WRAPPER!
        
    }
    
    // public functions
    
    public func getXmlObj() -> StorybookXml {
        
        if SBPLUS_XML_OBJ == nil {
            
            do {
                SBPLUS_XML_DOC = formatXML(doc: try XMLDocument(xmlString: emptyXML(), options: [.nodePreserveAll]))
                SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
                SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()
            } catch let error as NSError {
                NSLog(error.localizedDescription)
            }
            
            return SBPLUS_XML_OBJ!
            
        }
        
        return SBPLUS_XML_OBJ!
    }
    
    public func getXmlObjPages() -> Array<Page> {
        
        if numSections() == 1 {
            SBPLUS_XML_PAGES?.remove(at: 0)
        }
        
        return SBPLUS_XML_PAGES!
    }
    
    public func addSbPage(page: Page, index: IndexSet.Element = 0) {
        
        if index > 0 {
            SBPLUS_XML_PAGES!.insert(page, at: index)
        } else {
            SBPLUS_XML_PAGES!.append(page)
        }
        
        refreshPageCollectionWithNew(pages: SBPLUS_XML_PAGES!)
        
        self.updateChangeCount(.changeDone)
        
    }
    
    public func addSbSection(section: Page, index: IndexSet.Element = 0) {
        
        if numSections() == 0 {
            
            let firstSection: Page = Page()
            firstSection.type = "section"
            firstSection.title = "Untitled"
            SBPLUS_XML_PAGES!.insert(firstSection, at: 0)
            
        }
        
        if index > 0 {
            SBPLUS_XML_PAGES!.insert(section, at: index)
        } else {
            SBPLUS_XML_PAGES!.append(section)
        }
        
        refreshPageCollectionWithNew(pages: SBPLUS_XML_PAGES!)
        self.updateChangeCount(.changeDone)
        
    }
    
    public func deletePage(indexes: IndexSet) {
        
        var tempPages: Array<Page> = []
        
        for index in indexes {
            
            let type = SBPLUS_XML_PAGES![index].type
            let name = SBPLUS_XML_PAGES![index].src
            let frames = SBPLUS_XML_PAGES![index].frames
            let fileName = name + "." + SBPLUS_XML_OBJ!.pageImgFormat
            
            switch type {
            case PageTypes.IMAGE:
                removeFileFromAssetsDir(file: fileName, subDir: FileNames.PAGES_DIR)
            case PageTypes.IMAGE_AUDIO:
                removeFileFromAssetsDir(file: fileName, subDir: FileNames.PAGES_DIR)
                removeFileFromAssetsDir(file: name + "." + FileExtensions.MP3, subDir: FileNames.AUDIO_DIR)
                if fileExistsInAssetsDir(fileName: name + FileExtensions.VTT, subDirName: FileNames.AUDIO_DIR, asBool: true) as! Bool {
                    removeFileFromAssetsDir(file: name + "." + FileExtensions.VTT, subDir: FileNames.AUDIO_DIR)
                }
            case PageTypes.VIDEO:
                removeFileFromAssetsDir(file: name + "." + FileExtensions.MP4, subDir: FileNames.VIDEO_DIR)
                if fileExistsInAssetsDir(fileName: name + "." + FileExtensions.VTT, subDirName: FileNames.VIDEO_DIR, asBool: true) as! Bool {
                    removeFileFromAssetsDir(file: name + "." + FileExtensions.VTT, subDir: FileNames.VIDEO_DIR)
                }
            case PageTypes.BUNDLE:
                
                if frames.count == 0 {
                    
                    let fName = name + "-1." + SBPLUS_XML_OBJ!.pageImgFormat
                    removeFileFromAssetsDir(file: fName, subDir: FileNames.PAGES_DIR)
                    
                } else {
                    
                    for (i, _) in frames.enumerated() {
                        let fName = name + "-" + String(i + 1) + "." + SBPLUS_XML_OBJ!.pageImgFormat
                        removeFileFromAssetsDir(file: fName, subDir: FileNames.PAGES_DIR)
                    }
                    
                }
                
                removeFileFromAssetsDir(file: name + "." + FileExtensions.MP3, subDir: FileNames.AUDIO_DIR)
                
                if fileExistsInAssetsDir(fileName: name + FileExtensions.VTT, subDirName: FileNames.AUDIO_DIR, asBool: true) as! Bool {
                    removeFileFromAssetsDir(file: name + "." + FileExtensions.VTT, subDir: FileNames.AUDIO_DIR)
                }
            default:
                break
            }
            
            SBPLUS_XML_PAGES![index].type = "DEL"
        }
        
        for page in SBPLUS_XML_PAGES! {
            
            if page.type != "DEL" {
                tempPages.append(page)
            }
            
        }
        
        refreshPageCollectionWithNew(pages: tempPages)
        self.updateChangeCount(.changeDone)
        
    }
    
    public func getXmlFileWrapper() -> FileWrapper {
        return (self.DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.XML_FILE])!
    }
    
    public func removeFromAssetsWrapper(file: FileWrapper, at: String) {
        
        guard let fileWrapper = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[at] else { return }
        fileWrapper.removeFileWrapper(file)
        
    }
    
    public func getAssetFileWrapper(name: String, at: String) -> FileWrapper? {
        
        guard let fileWrapper = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[at]?.fileWrappers![name] else {
            return nil
        }
        
        return fileWrapper
    }
    
    public func addAssetsWrappersFile(name: String, path: URL, to: String) {
        
        let fileWrappers = DOC_WRAPPER?.fileWrappers
        
        // if assets folder exists
        if (fileWrappers?[FileNames.ASSET_DIR] != nil) {
            
            // get the assets folder
            let assetsFileWrappers = fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers
        
            // create to directory if it does not exist
            if (assetsFileWrappers?[to] == nil) {
                
                let folder = FileWrapper(directoryWithFileWrappers: [:])
                folder.preferredFilename = to
                fileWrappers?[FileNames.ASSET_DIR]?.addFileWrapper(folder)
                
            }
            
            let toFolderWrappers = assetsFileWrappers?[to]?.fileWrappers
            
            // create the file if it does not exist
            if (toFolderWrappers?[name] == nil) {
                
                do {
                    
                    let file = try FileWrapper(url: path, options: .withoutMapping)
                    file.preferredFilename = name
                    
                    fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers![to]!.addFileWrapper(file)
                    
                } catch let error as NSError {
                    
                    NSLog(error.localizedDescription)
                    
                }
                
            } else {
                
                fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers![to]!.removeFileWrapper((toFolderWrappers?[name])!)
                
                do {
                    
                    let fdata = try Data(contentsOf: path)
                    let file = FileWrapper(regularFileWithContents: fdata)
                    
                    file.preferredFilename = name
                    fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers![to]!.addFileWrapper(file)
                    
                } catch let error as NSError {
                    
                    NSLog(error.localizedDescription)
                    
                }
                
            }
            
        } // end assets folder check
        
    }
    
    public func addAssetsWrappersFile(name: String, file: FileWrapper, to: String) {
        
        let fileWrappers = DOC_WRAPPER?.fileWrappers
        
        // if assets folder exists
        if (fileWrappers?[FileNames.ASSET_DIR] != nil) {
            
            // get the assets folder
            let assetsFileWrappers = fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers
            
            // create to directory if it does not exist
            if (assetsFileWrappers?[to] == nil) {
                
                let folder = FileWrapper(directoryWithFileWrappers: [:])
                folder.preferredFilename = to
                fileWrappers?[FileNames.ASSET_DIR]?.addFileWrapper(folder)
                
            }
            
            let toFolderWrappers = assetsFileWrappers?[to]?.fileWrappers
            
            // create the file if it does not exist
            if (toFolderWrappers?[name] != nil) {
                fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers![to]!.removeFileWrapper((toFolderWrappers?[name])!)
            }
            
            let file = FileWrapper(regularFileWithContents: file.regularFileContents!)
            file.preferredFilename = name
            
            fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers![to]!.addFileWrapper(file)
            
        } // end assets folder check
        
    }
    
    public func fileExistsInAssetsDir(fileName: String, subDirName: String = "", asBool: Bool = false) -> Any {
        
        if subDirName.isEmpty {
            
            guard (DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[fileName]) != nil else { return false as Any }
            
            if asBool {
                return true as Any
            }
            
            return DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[fileName] as Any
            
        } else {
            
            guard (DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[subDirName]?.fileWrappers?[fileName]) != nil else { return false as Any }
            
            if asBool {
                return true as Any
            }
            
            return DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[subDirName]?.fileWrappers?[fileName] as Any
            
        }
        
    }
    
    public func fileWrapperExistsInRoot(name: String) -> Bool {
        guard (DOC_WRAPPER?.fileWrappers?[name]) != nil else { return false }
        return true
    }
    
    public func addDownloadFile(name: String, url: URL) {
        
        guard DOC_WRAPPER != nil else { return }
        
        do {
            
            let file = try FileWrapper(url: url, options: .withoutMapping)
            file.preferredFilename = name
            
            DOC_WRAPPER?.addFileWrapper(file)
            
        } catch let error as NSError {
            NSLog(error.localizedDescription)
        }
        
    }
    
    public func removeDownloadFile(file: String) {
        
        guard DOC_WRAPPER != nil else { return }
        guard let fileToRemove = DOC_WRAPPER?.fileWrappers?[file] else { return }
        
        DOC_WRAPPER?.removeFileWrapper(fileToRemove)
        
    }
    
    public func addFileToAssetsDir(name: String, path: URL) {
        
        guard let assetWrapper = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR] else { return }
        
        do {
            
            let file = try FileWrapper(url: path, options: .withoutMapping)
            file.preferredFilename = name
            
            assetWrapper.addFileWrapper(file)
            
        } catch let error as NSError {
            
            NSLog(error.localizedDescription)
            
        }
        
    }
    
    public func removeFileFromAssetsDir(file: String, subDir: String = "") {
        
        if subDir.isEmpty {
            
            guard let assetWrapper = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR] else { return }
            guard let fileToRemove = assetWrapper.fileWrappers?[file] else { return }
            
            assetWrapper.removeFileWrapper(fileToRemove)
            
        } else {
            
            guard let assetWrapper = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[subDir] else { return }
            guard let fileToRemove = assetWrapper.fileWrappers?[file] else { return }
            assetWrapper.removeFileWrapper(fileToRemove)
            
        }
        
    }
    
    func getFileNamePrefix() -> String {
        
        return fileNamePrefix
        
    }
    
    public func numSections() -> Int {
        
        var sectionCount: Int = 0
        
        for page in SBPLUS_XML_PAGES! {
            
            if page.type == PageTypes.SECTION {
                sectionCount += 1
            }
            
        }
        
        return sectionCount
        
    }
    
    public func refreshPageCollectionWithNew(pages: Array<Page>) {
        
        var newPages = pages
        
        if numSections() == 0 {
            
            let firstSection: Page = Page()
            firstSection.type = "section"
            firstSection.title = "Untitled"
            firstSection.number = 0
            newPages.insert(firstSection, at: 0)
            
        }
        
        SBPLUS_XML_OBJ!.sections = SBPLUS_XML_OBJ!.backToSectionsPages(pages: newPages)
        SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()
    }
    
    // private functions
    
    private func xmlToObj(doc: XMLDocument) -> StorybookXml {
        let sbParser: SbXmlParser = SbXmlParser()
        return sbParser.parse(xmlString: doc.xmlString)
    }
    
    private func emptyXML() -> String {
        
        let prefSettings = UserDefaults.standard
        let setup: Setup = Setup()
        var sections: Array<Section> = Array()
        
        for i in 0 ..< prefSettings.integer(forKey: Preferences.NUM_OF_SECTIONS) {
            
            let section = Section()
            
            section.title = "Section \(i + 1)"
            
            let page = Page()
            page.type = prefSettings.string(forKey: Preferences.PAGE_TYPE)!
            page.title = "Untitled"
            page.src = prefSettings.string(forKey: Preferences.ASSET_FILE_NAME)! + "01"
            
            let pages: Array<Page> = Array(repeating: page, count: prefSettings.integer(forKey: Preferences.NUM_OF_PAGES))
            
            section.pages = pages
            
            sections.append(section)
            
        }
        
        let SBPLUS_XML_OBJ: StorybookXml = StorybookXml(
            accent: "0c3b6b",
            imgFormat: prefSettings.string(forKey: Preferences.PAGE_IMG_FORMAT)!,
            splashFormat: prefSettings.string(forKey: Preferences.SPLASH_IMG_FORMAT)!,
            analytics: false,
            mathJax: false,
            setup: setup,
            sections: sections,
            xmlVersion: "3.1")
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

