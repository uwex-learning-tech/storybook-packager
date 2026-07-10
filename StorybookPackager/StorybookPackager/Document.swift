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
    
    private var fileNamePrefix: String?
    private var DOC_WRAPPER: FileWrapper?
    private var SBPLUS_XML_DOC:XMLDocument?
    private let XML_OPTIONS: XMLNode.Options = [XMLNode.Options.nodePreserveAll]
    private var SBPLUS_XML_OBJ: StorybookXml?
    private var SBPLUS_XML_PAGES: Array<Page>?
    private var _index: IndexSet = []
    private var trash: Array<(String, String)> = []
    private var previousDocName: String?
    private let saveProgressSheet = SaveProgressSheet()
    private var skipReleaseYearPrompt = false
    
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
        
        fileNamePrefix = UserDefaults.standard.string(forKey: Preferences.ASSET_FILE_NAME) ?? "page"
        
        let window = NSStoryboard(name: StoryboardNames.MAIN, bundle: nil).instantiateController(withIdentifier: WindowIdentifiers.PROJECT_WINDOW) as? ProjectWindowController
        
        self.addWindowController(window!)

    }
    
    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        
        let fileWrappers = fileWrapper.fileWrappers
        
        // throw error if asset directory is not found
        if (fileWrappers?[FileNames.ASSET_DIR] == nil) {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        
        // read XML file otherwise create blank xml and read
        let assetsDirWrappers = fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers
        let xmlWrapper: FileWrapper? = assetsDirWrappers?[FileNames.XML_FILE]
        
        if (xmlWrapper == nil) {
            
            SBPLUS_XML_DOC = formatXML(doc: try XMLDocument(xmlString: self.emptyXML(), options: XML_OPTIONS))
            SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
            SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()
            
        } else {
            
            let data: Data? = xmlWrapper?.regularFileContents
            
            if let aData = data {
                
                SBPLUS_XML_DOC = try XMLDocument(data: aData, options: XML_OPTIONS)
                SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
                SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()
                
            }
            
        }
        
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
        
        checkForDownloadableFiles( fileWrapper: DOC_WRAPPER! )
        
    }
    
    func checkForDownloadableFiles(fileWrapper: FileWrapper) {
        
        guard let fileWrappers = fileWrapper.fileWrappers else { return }

        // A document restored from an autosaved draft has no fileURL yet, so there is no document
        // name to rename the bundled downloadables to. They get renamed on the next real save.
        guard let fileURL = self.fileURL else { return }

        let docName: String = fileURL.deletingPathExtension().lastPathComponent
        var nameChanged: Bool = false
        
        for (_, file) in fileWrappers {
            
            if ( file.isRegularFile ) {
                
                let fileComponents = file.filename?.components( separatedBy: "." )
                guard let fileName = fileComponents?.first else { return }
                guard let fileExtension = fileComponents?.last else { return }
                
                if fileName != docName {
                    
                    switch fileExtension {
                    case "pdf":
                        
                        let fw = FileWrapper(regularFileWithContents: file.regularFileContents!)
                        fw.preferredFilename = docName + ".pdf"
                        
                        fileWrapper.addFileWrapper( fw )
                        fileWrapper.removeFileWrapper(file )
                        
                        nameChanged = true
                        
                    case "mp3":
                        
                        let fw = FileWrapper(regularFileWithContents: file.regularFileContents!)
                        fw.preferredFilename = docName + ".mp3"
                        
                        fileWrapper.addFileWrapper( fw )
                        fileWrapper.removeFileWrapper(file )
                        
                        nameChanged = true
                        
                    case "mp4":
                        
                        let fw = FileWrapper(regularFileWithContents: file.regularFileContents!)
                        fw.preferredFilename = docName + ".mp4"
                        
                        fileWrapper.addFileWrapper( fw )
                        fileWrapper.removeFileWrapper(file )
                        
                        nameChanged = true
                        
                    case "zip":
                        
                        let fw = FileWrapper(regularFileWithContents: file.regularFileContents!)
                        fw.preferredFilename = docName + ".zip"
                        
                        fileWrapper.addFileWrapper( fw )
                        fileWrapper.removeFileWrapper(file )
                        
                        nameChanged = true
                        
                    default: break // do nothing
                    }
                    
                }
                
            }
            
        }
        
        if nameChanged {

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // This save is a side effect of opening the document, not something the user asked
                // for; a year-less presentation must not be interrogated about its release year the
                // moment it opens. The next explicit save still prompts.
                self.skipReleaseYearPrompt = true
                self.save( nil )
            }

        }
        
    }
    
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {

        // Note: first-responder commit and any other main-thread-only work happens in
        // save(to:ofType:for:completionHandler:) before this is called. Under asynchronous writing
        // this method runs on a background thread, so it must not touch AppKit (e.g. NSApp/windows).

        // Release the main thread *now*, before the expensive snapshot work below (createTempFiles()
        // duplicates every asset's bytes, syncAssetNames()/cleanSweep() rebuild the wrapper tree).
        // By default NSDocument keeps the main thread blocked until fileWrapper(ofType:) returns, so
        // that work would still beachball the UI even though the disk write is asynchronous. Calling
        // unblockUserInteraction() here lets the progress sheet animate through the whole save. This
        // is a no-op during synchronous saves. It is safe to unblock before the snapshot exists only
        // because the modal save sheet prevents the document from being mutated while we build and
        // write it on this background thread.
        unblockUserInteraction()

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

            if let aData = try currentXmlData() {
                assetsFolder.addRegularFile(withContents: aData, preferredFilename: FileNames.XML_FILE)
            }

            DOC_WRAPPER?.addFileWrapper(assetsFolder)

        } else { // if asset directory does exist

            // get the xml file
            let xmlWrapper: FileWrapper? = fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.XML_FILE]

            let xmlData: Data? = try currentXmlData()

            // if it already exist, delete it
            if let xmlWrapper = xmlWrapper {
                fileWrappers?[FileNames.ASSET_DIR]?.removeFileWrapper(xmlWrapper)
            }

            // add/save the xml file
            if let aData = xmlData {
                fileWrappers?[FileNames.ASSET_DIR]?.addRegularFile(withContents: aData, preferredFilename: FileNames.XML_FILE)
            }

        } // end filewrapper in asset directory
        
        // clean
        syncAssetNames()
        removeRootDirFile(file: ".DS_Store")
        cleanSweep(filewrapper: DOC_WRAPPER!)
        emptyTrash()
        
        return DOC_WRAPPER!
        
    }
    
    // Serialize the in-memory presentation to the bytes that become assets/sbplus.xml.
    //
    // An empty presentation is seeded only when there is no model at all. A document being saved for
    // the first time has no assets/ wrapper yet but *does* have a model — one that may carry settings
    // collected moments earlier, such as the release year from the save gate below. Reseeding it from
    // emptyXML() at that point silently discarded them.
    private func currentXmlData() throws -> Data? {

        if SBPLUS_XML_OBJ == nil {

            SBPLUS_XML_DOC = formatXML(doc: try XMLDocument(xmlString: emptyXML(), options: XML_OPTIONS))
            SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
            SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()

        }

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

        return SBPLUS_XML_DOC!.xmlData

    }

    // Allow the heavy part of a save — writing every asset's bytes to disk — to run on a background
    // queue so the app no longer beachballs during saves of asset-heavy presentations. NSDocument
    // blocks the main thread only until fileWrapper(ofType:) has snapshotted the model, then writes
    // off the main thread. We gate this on having a visible window because the progress sheet shown
    // in save(to:ofType:for:completionHandler:) is what prevents the user from mutating the document
    // mid-write; without it, asynchronous writing would race the background writer.
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        return windowForSheet?.isVisible == true
    }

    // The single funnel every save routes through (⌘S, Save As, and the various save(nil) call
    // sites). Commits in-flight edits, shows a modal "Saving…" sheet over the document window for
    // the duration of the save, and tears it down when the write completes.
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {

        // A presentation must carry a release year — the player uses it to locate the splash image.
        // The year is only ever stored as the "_r<year>" suffix on `course` (SbXmlReader doesn't read
        // setup.releaseYear back), so that string is what we test. The gate lives here, the one place
        // every save funnels through on the main thread; fileWrapper(ofType:)/write(...) run on a
        // background thread under asynchronous writing and must not present a sheet.
        let promptForYear = !skipReleaseYearPrompt
        skipReleaseYearPrompt = false

        if promptForYear,
           ReleaseYear.parse(course: getXmlObj().setup.course).year == nil,
           let sheetHost = windowForSheet, sheetHost.isVisible,
           let presenter = sheetHost.contentViewController {

            let sheet = ReleaseYearSheetController(currentYear: ReleaseYear.current) { [weak self] year in

                guard let self = self else { return }

                var setup = self.getXmlObj().setup
                setup.course = ReleaseYear.compose(number: ReleaseYear.parse(course: setup.course).number, year: year)
                setup.releaseYear = ReleaseYear.suffix(for: year)

                self.getXmlObj().setSetup(setup: setup)
                self.updateChangeCount(.changeDone)

                // Re-enter: the course now carries a year, so the gate above falls through.
                self.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)

            }

            presenter.presentAsSheet(sheet)

            return

        }

        // Commit any in-flight text edits before the model is snapshotted. This used to happen inside
        // fileWrapper(ofType:), but that now runs on a background thread under asynchronous writing,
        // so the AppKit call has to be made here on the main thread instead.
        NSApp.keyWindow?.makeFirstResponder(nil)

        guard let host = windowForSheet, host.isVisible else {
            super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
            return
        }

        saveProgressSheet.begin(on: host, message: "Saving “\(displayName ?? "Presentation")”…")

        // Defer one runloop turn so the sheet actually paints before fileWrapper(ofType:) briefly
        // blocks the main thread to snapshot the model.
        DispatchQueue.main.async {
            super.save(to: url, ofType: typeName, for: saveOperation) { error in
                self.saveProgressSheet.end()
                completionHandler(error)
            }
        }

    }

    // Take over the actual on-disk write so we can drive a real, byte-accurate progress bar — the
    // one quantity that genuinely reflects save progress (NSDocument/FileWrapper report none). The
    // default chain would hand the whole tree to FileWrapper.write(to:) in one opaque call; instead
    // we walk the tree and write one file at a time, reporting bytes persisted as we go.
    //
    // We only populate `url` (a temporary directory NSDocument's writeSafely(...) hands us); the
    // atomic swap, version preservation, and file-attribute application around it are still done by
    // the default writeSafely(...), so this is not a reimplementation of safe-saving.
    //
    // NOTE: we deliberately do NOT use `absoluteOriginalContentsURL` for FileWrapper's hard-link
    // optimization. That optimization assumes a file of a given name is the previous revision of the
    // same name, but this app names asset files by page position (page01, page02, …) and renumbers
    // them on every save — so a name maps to different content across saves. Hard-linking against the
    // old package therefore corrupts pages on delete/insert/reorder. Every file is written in full.
    override func write(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, originalContentsURL absoluteOriginalContentsURL: URL?) throws {

        let root = try fileWrapper(ofType: typeName)   // builds the tree and calls unblockUserInteraction()

        let total = totalRegularFileBytes(of: root)
        var written: Int64 = 0
        var lastPercent = -1

        // Report progress to the sheet on the main thread, but at most once per whole percent so a
        // package with thousands of small files doesn't flood the main queue.
        func report() {
            guard total > 0 else { return }
            let percent = Int(Double(written) / Double(total) * 100)
            guard percent != lastPercent else { return }
            lastPercent = percent
            let fraction = Double(written) / Double(total)
            DispatchQueue.main.async { self.saveProgressSheet.update(fraction: fraction) }
        }

        try writeWrapper(root, to: url) { fileBytes in
            written += fileBytes
            report()
        }

        DispatchQueue.main.async { self.saveProgressSheet.update(fraction: 1) }

    }

    // Recursively write a file wrapper tree to `url`, invoking `progress` with each leaf file's byte
    // count as it lands on disk. Names come from the directory keys (an in-memory wrapper's own
    // `filename`/`preferredFilename` can be nil until it has been serialized once).
    private func writeWrapper(_ wrapper: FileWrapper, to url: URL, progress: (Int64) -> Void) throws {

        if wrapper.isDirectory {

            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)

            for (name, child) in wrapper.fileWrappers ?? [:] {
                try writeWrapper(child, to: url.appendingPathComponent(name), progress: progress)
            }

        } else {

            // Regular file or symlink — write its actual contents (no originalContentsURL; see the
            // note on write(to:ofType:for:originalContentsURL:) above).
            let bytes = regularFileSize(of: wrapper)
            try wrapper.write(to: url, options: [], originalContentsURL: nil)
            progress(bytes)

        }

    }

    // Size of a regular-file wrapper without forcing its contents into memory when possible:
    // fileAttributes carries the byte count for disk-backed wrappers.
    private func regularFileSize(of wrapper: FileWrapper) -> Int64 {
        if let size = wrapper.fileAttributes[FileAttributeKey.size.rawValue] as? NSNumber {
            return size.int64Value
        }
        return Int64(wrapper.regularFileContents?.count ?? 0)
    }

    // Total bytes of every regular file in the tree — the denominator for the progress bar.
    private func totalRegularFileBytes(of wrapper: FileWrapper) -> Int64 {
        if wrapper.isRegularFile {
            return regularFileSize(of: wrapper)
        }
        guard wrapper.isDirectory else { return 0 }
        var sum: Int64 = 0
        for (_, child) in wrapper.fileWrappers ?? [:] {
            sum += totalRegularFileBytes(of: child)
        }
        return sum
    }

    override func saveAs(_ sender: Any?) {
        previousDocName = self.fileURL?.deletingPathExtension().lastPathComponent
        runModalSavePanel(for: .saveAsOperation, delegate: self, didSave: #selector(self.didSaveAs), contextInfo: nil)
    }
    
    @objc private func didSaveAs() {
        
        let savedAsName = (self.fileURL?.deletingPathExtension().lastPathComponent)!
        
        if self.fileWrapperExistsInRoot(name: previousDocName! + ".pdf") {
            
            let file = FileWrapper(regularFileWithContents: (DOC_WRAPPER!.fileWrappers![previousDocName! + ".pdf"]?.regularFileContents)!)
            file.preferredFilename = savedAsName + ".pdf"
            
            DOC_WRAPPER?.addFileWrapper(file)
            DOC_WRAPPER?.removeFileWrapper((DOC_WRAPPER?.fileWrappers?[previousDocName! + ".pdf"])!)
            
        }
        
        if self.fileWrapperExistsInRoot(name: previousDocName! + ".mp3") {
            
            let file = FileWrapper(regularFileWithContents: (DOC_WRAPPER!.fileWrappers![previousDocName! + ".mp3"]?.regularFileContents)!)
            file.preferredFilename = savedAsName + ".mp3"
            
            DOC_WRAPPER?.addFileWrapper(file)
            DOC_WRAPPER?.removeFileWrapper((DOC_WRAPPER?.fileWrappers?[previousDocName! + ".mp3"])!)
            
        }
        
        if self.fileWrapperExistsInRoot(name: previousDocName! + ".mp4") {
            
            let file = FileWrapper(regularFileWithContents: (DOC_WRAPPER!.fileWrappers![previousDocName! + ".mp4"]?.regularFileContents)!)
            file.preferredFilename = savedAsName + ".mp4"
            
            DOC_WRAPPER?.addFileWrapper(file)
            DOC_WRAPPER?.removeFileWrapper((DOC_WRAPPER?.fileWrappers?[previousDocName! + ".mp4"])!)
            
        }
        
        if self.fileWrapperExistsInRoot(name: previousDocName! + ".zip") {
            
            let file = FileWrapper(regularFileWithContents: (DOC_WRAPPER!.fileWrappers![previousDocName! + ".zip"]?.regularFileContents)!)
            file.preferredFilename = savedAsName + ".zip"
            
            DOC_WRAPPER?.addFileWrapper(file)
            DOC_WRAPPER?.removeFileWrapper((DOC_WRAPPER?.fileWrappers?[previousDocName! + ".zip"])!)
            
        }
        
        self.save(nil)
        
    }
    
    // public functions
    
    public func getXmlObj() -> StorybookXml {
        
        if SBPLUS_XML_OBJ == nil {
            
            do {
                SBPLUS_XML_DOC = formatXML(doc: try XMLDocument(xmlString: emptyXML(), options: XML_OPTIONS))
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

        // Seed the model the way getXmlObj() does. An untitled document has never been through
        // read(from:ofType:), so its pages stay nil until fileWrapper(ofType:) runs — and under
        // asynchronous saving that happens after save(to:) has already returned to its caller.
        if SBPLUS_XML_PAGES == nil {
            SBPLUS_XML_PAGES = getXmlObj().getSectionAsPages()
        }

        if numSections() == 1 {
            SBPLUS_XML_PAGES?.remove(at: 0)
        }

        return SBPLUS_XML_PAGES ?? []
    }
    
    public func addSbPage(page: Page, index: IndexSet.Element = 0, refreash: Bool = true) {
        
        if index > 0 {
            SBPLUS_XML_PAGES!.insert(page, at: index)
        } else {
            SBPLUS_XML_PAGES!.append(page)
        }
        
        if refreash {
            refreshPageCollectionWithNew(pages: SBPLUS_XML_PAGES!)
        }
        
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
            
            SBPLUS_XML_PAGES![index].type = PageTypes._DEL
            
        }
        
        for page in SBPLUS_XML_PAGES! {
            
            if page.type != PageTypes._DEL {
                tempPages.append(page)
            }
            
        }
        
        refreshPageCollectionWithNew(pages: tempPages)
        self.updateChangeCount(.changeDone)
        
    }
    
    func cleanSweep(filewrapper: FileWrapper) {
        
        filewrapper.fileWrappers!.forEach({ (name, filewrapper) in
            
            switch name {
                
            case ".DS_Store":
                
                self.moveToTrash(file: (name, filewrapper.preferredFilename!))
            
            case FileNames.PAGES_DIR:
                
                filewrapper.fileWrappers?.forEach({ (name, file) in
                    
                    if file.isRegularFile {
                        
                        let ext = ".\(SBPLUS_XML_OBJ!.pageImgFormat)"
                        
                        if !SBPLUS_XML_PAGES!.contains(where: {
                            
                            switch $0.type {
                                
                            case PageTypes.IMAGE_AUDIO, PageTypes.IMAGE:
                                
                                return $0.src + ext == name
                                
                            case PageTypes.BUNDLE:
                                
                                var count = 1
                                
                                for _ in $0.frames {
                                    
                                    if ($0.src + "-\(count)\(ext)") == name {
                                        return true
                                    } else {
                                        count += 1
                                    }
                                    
                                }
                                
                                return false
                                
                            default: return false
                                
                            }
                            
                        }) {
                            self.moveToTrash(file: (name, filewrapper.preferredFilename!))
                        }
                        
                    }
                    
                })
                
            case FileNames.AUDIO_DIR:
                
                filewrapper.fileWrappers?.forEach({ (name, file) in
                    
                    if file.isRegularFile {
                        
                        if let index = name.lastIndex(of: ".") {
                            
                            if !SBPLUS_XML_PAGES!.contains(where: {
                                
                                switch $0.type {
                                    
                                case PageTypes.BUNDLE, PageTypes.IMAGE_AUDIO:
                                    
                                    return $0.src == name[..<index]
                                    
                                case PageTypes.QUIZ:
                                    
                                    guard $0.quiz.type == QuizTypes.MULTIPLE_ANSWER || $0.quiz.type == QuizTypes.MULTIPLE_CHOICE else { return false }
                                    
                                    var found = false
                                    
                                    if let questionAudio = $0.quiz.question["audio"] {
                                        
                                        if !questionAudio.isEmpty {
                                            if questionAudio == name { found = true; return found }
                                        }
                                        
                                    }
                                    
                                    for answer in $0.quiz.choices {
                                        
                                        if let audio = answer["audio"] {
                                            
                                            if !audio.isEmpty {
                                                if audio == name { found = true; break }
                                            }
                                            
                                        }
                                        
                                    }
                                    
                                    return found
                                    
                                default: return false
                                    
                                }
                                
                            }) {
                                
                                self.moveToTrash(file: (name, filewrapper.preferredFilename!))
                                
                            }
                            
                        }
                    }
                    
                })
                
            case FileNames.VIDEO_DIR:
                
                filewrapper.fileWrappers?.forEach({ (name, file) in
                    
                    if file.isRegularFile {
                        
                        if let index = name.lastIndex(of: ".") {
                            
                            if !SBPLUS_XML_PAGES!.contains(where: { $0.type == PageTypes.VIDEO && $0.src == name[..<index] }) {
                                self.moveToTrash(file: (name, filewrapper.preferredFilename!))
                            }
                            
                        }
                    }
                    
                })
                
            case FileNames.IMAGES_DIR:
                
                filewrapper.fileWrappers?.forEach({ (name, file) in
                    
                    if file.isRegularFile {
                        
                        if !SBPLUS_XML_PAGES!.contains(where: {
                            
                            if $0.type == PageTypes.QUIZ {
                                
                                guard $0.quiz.type == QuizTypes.MULTIPLE_ANSWER || $0.quiz.type == QuizTypes.MULTIPLE_CHOICE else { return false }
                                
                                if let questionAudio = $0.quiz.question["image"] {
                                    
                                    if !questionAudio.isEmpty {
                                        if questionAudio == name { return true }
                                    }
                                    
                                }
                                
                                for answer in $0.quiz.choices {
                                    
                                    if let audio = answer["image"] {
                                        
                                        if !audio.isEmpty {
                                            if audio == name { return true }
                                        }
                                        
                                    }
                                    
                                }
                                
                            }
                            
                            return false
                            
                        }) {
                            self.moveToTrash(file: (name, filewrapper.preferredFilename!))
                        }
                        
                    }
                    
                })
                
            default: break
            }
            
            if filewrapper.isDirectory && filewrapper.fileWrappers!.count > 0{
                cleanSweep(filewrapper: filewrapper)
            }
            
        })
    
    }
    
    fileprivate func moveToTrash(file: (String, String)) {
        self.trash.append(file)
    }
    
    fileprivate func emptyTrash() {
        
        self.trash.forEach({ (arg) in
            
            let (name, directory) = arg
            
            switch directory {
                
            case FileNames.ASSET_DIR:
                removeFileFromAssetsDir(file: name)
            default:
                removeFileFromAssetsDir(file: name, subDir: directory)
                
            }
            
        })
        
        self.trash = []
        
    }
    
    private func getTrash() -> Array<(String, String)> {
        return self.trash
    }
    
    public func getXmlFileWrapper() -> FileWrapper {
        return (self.DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.XML_FILE])!
    }
    
    public func removeFromAssetsWrapper(file: FileWrapper, at: String) {
        
        guard let fileWrapper = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[at] else { return }
        fileWrapper.removeFileWrapper(file)
        
    }
    
    public func getAssetFileWrapper(name: String, at: String) -> FileWrapper? {
        return DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[at]?.fileWrappers?[name]
    }

    // MARK: - Quiz audio (assets/audio/quiz/)
    //
    // The player resolves quiz media as `assets/audio/<value>`, where <value> is the string stored
    // in a quiz <question>/<answer> audio="" attribute (e.g. "quiz/page22_quiz.mp3"). We store quiz
    // audio under assets/audio/quiz/ and set the attribute to "quiz/<filename>".

    // Resolve a path relative to assets/audio/ (the raw audio="" attribute value). Handles both a
    // bare filename ("x.mp3") and a subfolder path ("quiz/x.mp3"). Returns nil if it isn't a file.
    public func getAudioAssetWrapper(relativePath: String) -> FileWrapper? {

        var wrapper = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.AUDIO_DIR]

        for component in relativePath.split(separator: "/") {
            wrapper = wrapper?.fileWrappers?[String(component)]
        }

        return (wrapper?.isRegularFile == true) ? wrapper : nil

    }

    // Copy an audio file into assets/audio/quiz/, creating the audio and quiz folders as needed,
    // replacing any existing file of the same name. Returns the attribute value ("quiz/<name>") to
    // store on the quiz question/answer, or nil on failure.
    @discardableResult
    public func addQuizAudioFile(name: String, from url: URL) -> String? {

        do {
            let data = try Data(contentsOf: url)
            return addQuizAudioFile(name: name, data: data)
        } catch let error as NSError {
            NSLog(error.localizedDescription)
            return nil
        }

    }

    // Bytes-based sibling of addQuizAudioFile(name:from:), used when adopting a quiz audio clip
    // carried in a pasteboard payload (we hold its bytes, not a file URL).
    @discardableResult
    public func addQuizAudioFile(name: String, data: Data) -> String? {

        guard let assets = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR] else { return nil }

        // ensure assets/audio
        if assets.fileWrappers?[FileNames.AUDIO_DIR] == nil {
            let audioFolder = FileWrapper(directoryWithFileWrappers: [:])
            audioFolder.preferredFilename = FileNames.AUDIO_DIR
            assets.addFileWrapper(audioFolder)
        }

        guard let audioDir = assets.fileWrappers?[FileNames.AUDIO_DIR] else { return nil }

        // ensure assets/audio/quiz
        if audioDir.fileWrappers?[FileNames.QUIZ_DIR] == nil {
            let quizFolder = FileWrapper(directoryWithFileWrappers: [:])
            quizFolder.preferredFilename = FileNames.QUIZ_DIR
            audioDir.addFileWrapper(quizFolder)
        }

        guard let quizDir = audioDir.fileWrappers?[FileNames.QUIZ_DIR] else { return nil }

        if let existing = quizDir.fileWrappers?[name] {
            quizDir.removeFileWrapper(existing)
        }

        let file = FileWrapper(regularFileWithContents: data)
        file.preferredFilename = name
        quizDir.addFileWrapper(file)

        return FileNames.QUIZ_DIR + "/" + name

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
            
            // only regular files can be copied; calling regularFileContents on a directory wrapper
            // raises an exception that escapes the save's file-coordination block and leaks its
            // access claim (deadlocking all later document I/O). Skip non-files to preserve them as-is.
            guard file.isRegularFile, let contents = file.regularFileContents else { return }

            // create the file if it does not exist
            if (toFolderWrappers?[name] != nil) {
                fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers![to]!.removeFileWrapper((toFolderWrappers?[name])!)
            }

            let newFile = FileWrapper(regularFileWithContents: contents)
            newFile.preferredFilename = name

            fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers![to]!.addFileWrapper(newFile)
            
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
    
    public func removeRootDirFile(file: String) {
        
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
        
        guard fileNamePrefix != nil else { return "" }
        
        return fileNamePrefix!
        
    }
    
    public func numSections() -> Int {
        
        var sectionCount: Int = 0

        for page in SBPLUS_XML_PAGES ?? [] {

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
        //syncAssetNames()

    }

    // MARK: - Cross-presentation copy / paste of sections & pages
    //
    // These three methods implement copy-only transfer of sections and pages between presentations
    // (drag-and-drop and ⌘C/⌘V). The copy path is strictly read-only on the source: it reads the
    // pages and their asset bytes and serializes a throwaway StorybookXml — it never mutates the
    // source's pages or asset files. The paste path parses fresh Page objects from that XML, adopts
    // the carried asset bytes into this document under non-colliding names, and inserts via the same
    // refreshPageCollectionWithNew() path the intra-document reorder uses.

    // Build a self-contained pasteboard payload for the given outline rows. Read-only on `self`.
    // Returns nil if nothing copyable was selected.
    public func makePagesClipboardData(forFlatRows rows: IndexSet) -> Data? {

        guard !rows.isEmpty else { return nil }

        let flat = getXmlObjPages()
        guard !flat.isEmpty else { return nil }

        // Expand the selection: a selected SECTION also pulls in every following page until the
        // next section. De-dup while preserving ascending order.
        var ordered: [Int] = []
        var seen = Set<Int>()
        var hasRealSections = false

        func add(_ i: Int) {
            guard flat.indices.contains(i), !seen.contains(i) else { return }
            seen.insert(i)
            ordered.append(i)
        }

        for row in rows.sorted() {
            guard flat.indices.contains(row) else { continue }
            add(row)
            if flat[row].type == PageTypes.SECTION {
                hasRealSections = true
                var j = row + 1
                while flat.indices.contains(j) && flat[j].type != PageTypes.SECTION {
                    add(j)
                    j += 1
                }
            }
        }

        guard let firstIdx = ordered.first else { return nil }

        // backToSectionsPages requires the fragment to begin with a section. If the selection starts
        // mid-section, synthesize a leading section carrying the owning section's title.
        var fragment: [Page] = []

        if flat[firstIdx].type != PageTypes.SECTION {
            let section = Page()
            section.type = PageTypes.SECTION
            section.title = owningSectionTitle(flat: flat, before: firstIdx)
            fragment.append(section)
        }

        for i in ordered {
            fragment.append(flat[i])
        }

        // Serialize the fragment by reusing the existing XML round-trip on a throwaway StorybookXml.
        // backToSectionsPages copy()s the pages into the temp only — the source pages are untouched.
        let src = getXmlObj()
        let imgFormat = src.pageImgFormat

        let temp = StorybookXml(
            accent: src.accent,
            imgFormat: src.pageImgFormat,
            splashFormat: src.splashImgFormat,
            analytics: src.analytics,
            mathJax: src.mathJax,
            setup: src.setup,
            sections: [],
            xmlVersion: src.version)

        temp.sections = temp.backToSectionsPages(pages: fragment)
        let xmlData = Data(temp.toString().utf8)

        // Collect the bytes of every asset referenced by the copied pages (read-only getters only).
        var assets: [PageClipboard.Asset] = []
        var assetSeen = Set<String>()

        func collect(_ subdir: String, _ name: String, _ wrapper: FileWrapper?) {
            guard !name.isEmpty, let w = wrapper, w.isRegularFile, let bytes = w.regularFileContents else { return }
            let key = subdir + "/" + name
            guard !assetSeen.contains(key) else { return }
            assetSeen.insert(key)
            assets.append(PageClipboard.Asset(subdir: subdir, name: name, bytes: bytes))
        }

        func collectAudioRef(_ relPath: String) {
            guard !relPath.isEmpty else { return }
            let name = (relPath as NSString).lastPathComponent
            let dir = (relPath as NSString).deletingLastPathComponent
            let subdir = dir.isEmpty ? FileNames.AUDIO_DIR : FileNames.AUDIO_DIR + "/" + dir
            collect(subdir, name, getAudioAssetWrapper(relativePath: relPath))
        }

        func collectQuizDict(_ dict: [String: String]) {
            if let image = dict["image"], !image.isEmpty {
                collect(FileNames.IMAGES_DIR, image, getAssetFileWrapper(name: image, at: FileNames.IMAGES_DIR))
            }
            if let audio = dict["audio"], !audio.isEmpty {
                collectAudioRef(audio)
            }
        }

        for page in fragment {

            switch page.type {

            case PageTypes.IMAGE:

                let img = page.src + "." + imgFormat
                collect(FileNames.PAGES_DIR, img, getAssetFileWrapper(name: img, at: FileNames.PAGES_DIR))

            case PageTypes.IMAGE_AUDIO:

                let img = page.src + "." + imgFormat
                collect(FileNames.PAGES_DIR, img, getAssetFileWrapper(name: img, at: FileNames.PAGES_DIR))

                let mp3 = page.src + "." + FileExtensions.MP3
                collect(FileNames.AUDIO_DIR, mp3, getAssetFileWrapper(name: mp3, at: FileNames.AUDIO_DIR))

                let vtt = page.src + "." + FileExtensions.VTT
                collect(FileNames.AUDIO_DIR, vtt, getAssetFileWrapper(name: vtt, at: FileNames.AUDIO_DIR))

            case PageTypes.BUNDLE:

                // The flat page carries one frame per image (with a leading "00:00"), so the image
                // file count equals frames.count; fall back to a single image when empty.
                let count = max(page.frames.count, 1)
                for i in 1...count {
                    let fn = page.src + "-\(i)." + imgFormat
                    collect(FileNames.PAGES_DIR, fn, getAssetFileWrapper(name: fn, at: FileNames.PAGES_DIR))
                }

                let mp3 = page.src + "." + FileExtensions.MP3
                collect(FileNames.AUDIO_DIR, mp3, getAssetFileWrapper(name: mp3, at: FileNames.AUDIO_DIR))

                let vtt = page.src + "." + FileExtensions.VTT
                collect(FileNames.AUDIO_DIR, vtt, getAssetFileWrapper(name: vtt, at: FileNames.AUDIO_DIR))

            case PageTypes.VIDEO:

                let mp4 = page.src + "." + FileExtensions.MP4
                collect(FileNames.VIDEO_DIR, mp4, getAssetFileWrapper(name: mp4, at: FileNames.VIDEO_DIR))

                let vtt = page.src + "." + FileExtensions.VTT
                collect(FileNames.VIDEO_DIR, vtt, getAssetFileWrapper(name: vtt, at: FileNames.VIDEO_DIR))

            case PageTypes.HTML:

                // An HTML page is a self-contained directory at assets/html/<src>/ (index.html plus
                // its own nested assets, e.g. audio/). Carry the whole tree as a serialized wrapper.
                // Fall back to a single file for older projects that stored one.
                if let w = getAssetFileWrapper(name: page.src, at: FileNames.HTML_DIR), w.isDirectory {
                    if !assetSeen.contains(FileNames.HTML_DIR + "/" + page.src), let serialized = w.serializedRepresentation {
                        assetSeen.insert(FileNames.HTML_DIR + "/" + page.src)
                        assets.append(PageClipboard.Asset(subdir: FileNames.HTML_DIR, name: page.src, bytes: serialized, isDir: true))
                    }
                } else {
                    collect(FileNames.HTML_DIR, page.src, getAssetFileWrapper(name: page.src, at: FileNames.HTML_DIR))
                    let html = page.src + "." + FileExtensions.HTML
                    collect(FileNames.HTML_DIR, html, getAssetFileWrapper(name: html, at: FileNames.HTML_DIR))
                }
                // a separate narration track (the <audio src> attribute), if any
                collectAudioRef(page.audio)

            case PageTypes.QUIZ:

                collectQuizDict(page.quiz.question)
                for choice in page.quiz.choices {
                    collectQuizDict(choice)
                }

            default:
                // SECTION and URL-only types (youtube/vimeo/kaltura) carry no files.
                break

            }

        }

        return PageClipboard.makePlist(pageImgFormat: imgFormat, hasRealSections: hasRealSections, xml: xmlData, assets: assets)

    }

    // Walk backwards through the flat outline list to find the title of the section that owns the
    // page at `idx`; fall back to the document's first section title.
    private func owningSectionTitle(flat: [Page], before idx: Int) -> String {
        var i = idx - 1
        while i >= 0 {
            if flat[i].type == PageTypes.SECTION { return flat[i].title }
            i -= 1
        }
        return getXmlObj().sections.first?.title ?? "Untitled"
    }

    // Insert a previously-built clipboard payload at the given flat outline index. Adopts the carried
    // asset bytes into this document under non-colliding names and remaps each page's references.
    // Returns the number of inserted (non-section) pages, or nil if the payload was unusable.
    public func insertClipboardData(_ data: Data, atFlatIndex insertIndex: Int) -> Int? {

        guard let payload = PageClipboard.parsePlist(data) else { return nil }

        let xmlString = String(decoding: payload.xml, as: UTF8.self)
        var incoming = SbXmlParser().parse(xmlString: xmlString).getSectionAsPages()
        guard !incoming.isEmpty else { return nil }

        // If the copy didn't include a real section, drop the synthetic leading section so the pages
        // merge into the destination's existing section rather than starting a new one.
        if !payload.hasRealSections && getXmlObj().sections.count >= 1 {
            if incoming.first?.type == PageTypes.SECTION {
                incoming.removeFirst()
            }
        }

        // Adopt assets and remap references on each page.
        let destImgFmt = getXmlObj().pageImgFormat

        var assetMap: [String: Data] = [:]
        var dirMap: [String: Data] = [:]   // serialized directory trees (HTML pages), keyed by source name
        for asset in payload.assets {
            if asset.isDir {
                dirMap[asset.subdir + "/" + asset.name] = asset.bytes
            } else {
                assetMap[asset.subdir + "/" + asset.name] = asset.bytes
            }
        }

        for page in incoming {
            remapPage(page, payload: payload, assetMap: assetMap, dirMap: dirMap, destImgFmt: destImgFmt)
        }

        // Insert into the flat page list and rebuild — same path as the intra-document reorder.
        var pages = getXmlObjPages()
        var idx = insertIndex
        if idx < 0 || idx > pages.count { idx = pages.count }

        for page in incoming {
            pages.insert(page, at: idx)
            idx += 1
        }

        refreshPageCollectionWithNew(pages: pages)
        self.updateChangeCount(.changeDone)

        return incoming.filter { $0.type != PageTypes.SECTION }.count

    }

    // Remap one freshly-parsed page's asset references to names adopted into this document.
    private func remapPage(_ page: Page, payload: PageClipboard.Payload, assetMap: [String: Data], dirMap: [String: Data], destImgFmt: String) {

        let original = page.src

        switch page.type {

        case PageTypes.IMAGE:

            // Single image. syncAssetNames() renumbers it on save, so it must exist under page.src.
            let base = reserveBase(proposed: original) { b in
                [(FileNames.PAGES_DIR, b + "." + destImgFmt)]
            }
            if let bytes = assetMap[FileNames.PAGES_DIR + "/" + original + "." + payload.pageImgFormat] {
                writeAssetBytes(subdir: FileNames.PAGES_DIR, name: base + "." + destImgFmt, bytes: bytes)
            }
            page.src = base

        case PageTypes.IMAGE_AUDIO:

            // Image + narration (+ optional captions) share a base; reserve one free for all of them
            // so they stay paired when syncAssetNames() renumbers them on save.
            let base = reserveBase(proposed: original) { b in
                [(FileNames.PAGES_DIR, b + "." + destImgFmt),
                 (FileNames.AUDIO_DIR, b + "." + FileExtensions.MP3),
                 (FileNames.AUDIO_DIR, b + "." + FileExtensions.VTT)]
            }
            if let bytes = assetMap[FileNames.PAGES_DIR + "/" + original + "." + payload.pageImgFormat] {
                writeAssetBytes(subdir: FileNames.PAGES_DIR, name: base + "." + destImgFmt, bytes: bytes)
            }
            if let bytes = assetMap[FileNames.AUDIO_DIR + "/" + original + "." + FileExtensions.MP3] {
                writeAssetBytes(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.MP3, bytes: bytes)
            }
            if let bytes = assetMap[FileNames.AUDIO_DIR + "/" + original + "." + FileExtensions.VTT] {
                writeAssetBytes(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.VTT, bytes: bytes)
            }
            page.src = base

        case PageTypes.BUNDLE:

            let frameCount = max(page.frames.count, 1)
            let base = reserveBase(proposed: original) { b in
                var files: [(String, String)] = []
                for i in 1...frameCount {
                    files.append((FileNames.PAGES_DIR, b + "-\(i)." + destImgFmt))
                }
                files.append((FileNames.AUDIO_DIR, b + "." + FileExtensions.MP3))
                files.append((FileNames.AUDIO_DIR, b + "." + FileExtensions.VTT))
                return files
            }
            for i in 1...frameCount {
                if let bytes = assetMap[FileNames.PAGES_DIR + "/" + original + "-\(i)." + payload.pageImgFormat] {
                    writeAssetBytes(subdir: FileNames.PAGES_DIR, name: base + "-\(i)." + destImgFmt, bytes: bytes)
                }
            }
            if let bytes = assetMap[FileNames.AUDIO_DIR + "/" + original + "." + FileExtensions.MP3] {
                writeAssetBytes(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.MP3, bytes: bytes)
            }
            if let bytes = assetMap[FileNames.AUDIO_DIR + "/" + original + "." + FileExtensions.VTT] {
                writeAssetBytes(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.VTT, bytes: bytes)
            }
            page.src = base

        case PageTypes.VIDEO:

            let base = reserveBase(proposed: original) { b in
                [(FileNames.VIDEO_DIR, b + "." + FileExtensions.MP4),
                 (FileNames.VIDEO_DIR, b + "." + FileExtensions.VTT)]
            }
            if let bytes = assetMap[FileNames.VIDEO_DIR + "/" + original + "." + FileExtensions.MP4] {
                writeAssetBytes(subdir: FileNames.VIDEO_DIR, name: base + "." + FileExtensions.MP4, bytes: bytes)
            }
            if let bytes = assetMap[FileNames.VIDEO_DIR + "/" + original + "." + FileExtensions.VTT] {
                writeAssetBytes(subdir: FileNames.VIDEO_DIR, name: base + "." + FileExtensions.VTT, bytes: bytes)
            }
            page.src = base

        case PageTypes.HTML:

            // HTML pages aren't renumbered by syncAssetNames(), so set the adopted name now.
            if let bytes = dirMap[FileNames.HTML_DIR + "/" + original], let dir = FileWrapper(serializedRepresentation: bytes) {
                // The page's content is a whole directory tree; reconstruct it under a free name.
                let name = uniqueChildName(proposed: original, inSubdir: FileNames.HTML_DIR)
                addDirectoryWrapper(dir, name: name, to: FileNames.HTML_DIR)
                page.src = name
            } else if let bytes = assetMap[FileNames.HTML_DIR + "/" + original] {
                // legacy: a single file stored under exactly <src>
                page.src = adoptAsset(subdir: FileNames.HTML_DIR, proposedName: original, bytes: bytes)
            } else if let bytes = assetMap[FileNames.HTML_DIR + "/" + original + "." + FileExtensions.HTML] {
                // legacy: a single file stored under <src>.html
                let adopted = adoptAsset(subdir: FileNames.HTML_DIR, proposedName: original + "." + FileExtensions.HTML, bytes: bytes)
                page.src = (adopted as NSString).deletingPathExtension
            }
            if !page.audio.isEmpty {
                page.audio = adoptAudioRef(page.audio, assetMap: assetMap)
            }

        case PageTypes.QUIZ:

            // Quiz assets aren't renumbered by syncAssetNames() either; set adopted names now.
            var question = page.quiz.question
            remapQuizDict(&question, assetMap: assetMap)
            page.quiz.question = question

            for i in page.quiz.choices.indices {
                var choice = page.quiz.choices[i]
                remapQuizDict(&choice, assetMap: assetMap)
                page.quiz.choices[i] = choice
            }

        default:
            // SECTION and URL-only types carry no files.
            break

        }

    }

    private func remapQuizDict(_ dict: inout [String: String], assetMap: [String: Data]) {

        if let image = dict["image"], !image.isEmpty,
           let bytes = assetMap[FileNames.IMAGES_DIR + "/" + image] {
            dict["image"] = adoptAsset(subdir: FileNames.IMAGES_DIR, proposedName: image, bytes: bytes)
        }

        if let audio = dict["audio"], !audio.isEmpty {
            dict["audio"] = adoptAudioRef(audio, assetMap: assetMap)
        }

    }

    // Adopt an audio file referenced by a path relative to assets/audio (a bare name or "quiz/x.mp3")
    // and return the new relative reference, preserving any subfolder prefix.
    private func adoptAudioRef(_ relPath: String, assetMap: [String: Data]) -> String {

        let name = (relPath as NSString).lastPathComponent
        let dir = (relPath as NSString).deletingLastPathComponent
        let subdir = dir.isEmpty ? FileNames.AUDIO_DIR : FileNames.AUDIO_DIR + "/" + dir

        guard let bytes = assetMap[subdir + "/" + name] else { return relPath }

        let adopted = adoptAsset(subdir: subdir, proposedName: name, bytes: bytes)
        return dir.isEmpty ? adopted : dir + "/" + adopted

    }

    // Find a base name (no extension) such that every file slot the page would occupy is free in this
    // document, preferring `proposed` and otherwise appending "_copy<N>". Keeps multi-file page types
    // (image+audio+captions, bundle frames) paired under one base.
    private func reserveBase(proposed: String, filesFor: (String) -> [(String, String)]) -> String {

        func allFree(_ base: String) -> Bool {
            for (subdir, name) in filesFor(base) {
                if getAssetFileWrapper(name: name, at: subdir) != nil { return false }
            }
            return true
        }

        if allFree(proposed) { return proposed }

        var n = 1
        while true {
            let candidate = "\(proposed)_copy\(n)"
            if allFree(candidate) { return candidate }
            n += 1
        }

    }

    // Write asset bytes into assets/<subdir>/<name>, replacing any same-named file there.
    private func writeAssetBytes(subdir: String, name: String, bytes: Data) {
        let file = FileWrapper(regularFileWithContents: bytes)
        file.preferredFilename = name
        addAssetsWrappersFile(name: name, file: file, to: subdir)
    }

    // Pick a name that doesn't already exist as a child of assets/<subdir>, preferring `proposed`
    // and otherwise appending "_copy<N>". Used for directory-valued assets (HTML pages) that
    // syncAssetNames() never renumbers, so the name chosen here is the final one.
    private func uniqueChildName(proposed: String, inSubdir subdir: String) -> String {
        let container = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[subdir]
        func free(_ n: String) -> Bool { container?.fileWrappers?[n] == nil }
        if free(proposed) { return proposed }
        var n = 1
        while true {
            let candidate = "\(proposed)_copy\(n)"
            if free(candidate) { return candidate }
            n += 1
        }
    }

    // Add a directory FileWrapper (e.g. a whole HTML page folder) under assets/<subdir>/<name>,
    // creating the subdir if needed and replacing any same-named entry. addAssetsWrappersFile only
    // accepts regular files, so directory trees are added here.
    private func addDirectoryWrapper(_ dir: FileWrapper, name: String, to subdir: String) {
        guard let assets = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR] else { return }
        if assets.fileWrappers?[subdir] == nil {
            let folder = FileWrapper(directoryWithFileWrappers: [:])
            folder.preferredFilename = subdir
            assets.addFileWrapper(folder)
        }
        guard let container = assets.fileWrappers?[subdir] else { return }
        if let existing = container.fileWrappers?[name] { container.removeFileWrapper(existing) }
        dir.preferredFilename = name
        container.addFileWrapper(dir)
    }

    // Collision-safe single-file asset writer for types not renumbered on save (html, quiz). Reuses
    // the name if an identical-bytes file already exists; otherwise writes under a unique
    // "<base>_copy<N>.<ext>" name when a different file occupies the proposed name. Returns the
    // adopted filename. Quiz audio (subdir "audio/quiz") is routed through addQuizAudioFile.
    public func adoptAsset(subdir: String, proposedName: String, bytes: Data) -> String {

        let isQuizAudio = subdir == FileNames.AUDIO_DIR + "/" + FileNames.QUIZ_DIR

        func existing(_ name: String) -> FileWrapper? {
            if isQuizAudio {
                return getAudioAssetWrapper(relativePath: FileNames.QUIZ_DIR + "/" + name)
            }
            return getAssetFileWrapper(name: name, at: subdir)
        }

        func write(_ name: String) {
            if isQuizAudio {
                addQuizAudioFile(name: name, data: bytes)
            } else {
                writeAssetBytes(subdir: subdir, name: name, bytes: bytes)
            }
        }

        // Free name → write it.
        if existing(proposedName) == nil {
            write(proposedName)
            return proposedName
        }

        // Same name, identical bytes → reuse, no write needed.
        if existing(proposedName)?.regularFileContents == bytes {
            return proposedName
        }

        // Different file occupies the name → find a unique copy name (reusing an identical copy).
        let ns = proposedName as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension

        var n = 1
        while true {
            let candidate = ext.isEmpty ? "\(base)_copy\(n)" : "\(base)_copy\(n).\(ext)"
            if let found = existing(candidate) {
                if found.regularFileContents == bytes { return candidate }
            } else {
                write(candidate)
                return candidate
            }
            n += 1
        }

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
            page.title = "[Untitled]"
            page.src = getFileNamePrefix() + "01"
            
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
            
            return try XMLDocument(xmlString: doc.xmlString(options:[.nodePrettyPrint, .nodeCompactEmptyElement]), options: XML_OPTIONS)
            
        } catch let error as NSError {
            
            NSLog(error.localizedDescription)
            
        }
        
        return doc
        
    }
    
    // Snapshot the asset files that syncAssetNames() is about to rename into "~"-prefixed copies it
    // can read from while it overwrites the originals. Only the files named in `needed` are copied:
    // duplicating every asset's bytes on every save (even ones that aren't being renamed) was the
    // main cost of saving asset-heavy presentations, and a stable re-save renames nothing at all.
    private func createTempFiles(renaming needed: [String: Set<String>]) {

        let directories = [FileNames.PAGES_DIR, FileNames.AUDIO_DIR, FileNames.VIDEO_DIR]

        for directory in directories {

            guard let neededNames = needed[directory], !neededNames.isEmpty else { continue }

            if let items = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[directory]?.fileWrappers {
                for item in items {

                    // only regular files get temp copies; skip subdirectories (e.g. audio/quiz/) and
                    // any other content the packager doesn't manage so it is preserved untouched on save
                    guard item.value.isRegularFile else { continue }

                    // Use the dictionary key, not item.value.filename: a FileWrapper created in
                    // memory (e.g. an asset just written by paste/drop) has a nil `filename` until
                    // it's been serialized to disk, even though its key here is correct. Relying on
                    // `filename` skipped those wrappers, so syncAssetNames() couldn't find a "~" temp
                    // to rename from and the freshly-pasted assets were dropped on the first save.
                    let fn = item.key

                    guard neededNames.contains(fn) else { continue }

                    if !(fileExistsInAssetsDir(fileName: "~" + fn, subDirName: directory, asBool: true) as! Bool) {
                        addAssetsWrappersFile(name: "~" + fn, file: item.value, to: directory)
                    }

                }
            }

        }

    }

    // Build the set of asset files (keyed by directory) that will be renamed during this save, so
    // createTempFiles(renaming:) only duplicates those. Mirrors exactly the filename construction and
    // page numbering of the rename loop in syncAssetNames() below — a file is listed only when its
    // page's computed name differs from its current src.
    private func assetRenameSnapshotPlan(pages: [Page]) -> [String: Set<String>] {

        let imgFormat = SBPLUS_XML_OBJ!.pageImgFormat

        var needed: [String: Set<String>] = [:]
        func need(_ dir: String, _ name: String) { needed[dir, default: []].insert(name) }

        var count = 1

        for page in pages {

            let pageNumber = Util.shared.formatPageNum(num: count)
            let oldName = page.src
            let newName = fileNamePrefix! + pageNumber

            count += 1

            if oldName.isEmpty || oldName == newName { continue }

            switch page.type {

            case PageTypes.IMAGE:
                need(FileNames.PAGES_DIR, oldName + "." + imgFormat)

            case PageTypes.IMAGE_AUDIO:
                need(FileNames.PAGES_DIR, oldName + "." + imgFormat)
                need(FileNames.AUDIO_DIR, oldName + "." + FileExtensions.MP3)
                need(FileNames.AUDIO_DIR, oldName + "." + FileExtensions.VTT)

            case PageTypes.BUNDLE:
                for (i, _) in page.frames.enumerated() {
                    need(FileNames.PAGES_DIR, oldName + "-\(i + 1)." + imgFormat)
                }
                need(FileNames.AUDIO_DIR, oldName + "." + FileExtensions.MP3)
                need(FileNames.AUDIO_DIR, oldName + "." + FileExtensions.VTT)

            case PageTypes.VIDEO:
                need(FileNames.VIDEO_DIR, oldName + "." + FileExtensions.MP4)
                need(FileNames.VIDEO_DIR, oldName + "." + FileExtensions.VTT)

            default:
                break

            }

        }

        return needed

    }
    
    // Rename assets/<subdir>/<oldBase>.<ext> to <newBase>.<ext> during save, mirroring the image/audio
    // rename pattern: reads from the "~" temp copy created by createTempFiles(). No-op when the file
    // is absent or the name is unchanged. Used to keep .vtt captions paired with their renumbered
    // media (syncAssetNames historically renamed the image/audio/video but left captions orphaned).
    private func renameAssetFileOnSave(subdir: String, oldBase: String, newBase: String, ext: String) {

        guard oldBase != newBase else { return }
        guard let dir = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[subdir] else { return }

        let oldFileName = oldBase + "." + ext
        let newFileName = newBase + "." + ext

        guard dir.fileWrappers!.contains(where: { $0.key == oldFileName }) else { return }
        guard let data = dir.fileWrappers![("~" + oldFileName)]?.regularFileContents else { return }

        let newFile = FileWrapper(regularFileWithContents: data)
        newFile.preferredFilename = newFileName
        addAssetsWrappersFile(name: newFileName, file: newFile, to: subdir)

    }

    private func syncAssetNames() {

        let pages = SBPLUS_XML_PAGES?.filter{ $0.type != PageTypes.SECTION } ?? []

        // Snapshot only the files that are actually being renamed (often none on a re-save).
        createTempFiles(renaming: assetRenameSnapshotPlan(pages: pages))

        var count = 1;

        for page in pages {
            
            let pageNumber = Util.shared.formatPageNum(num: count)
            let oldName = page.src
            let newName = fileNamePrefix! + pageNumber
            
            count = count + 1
            
            if oldName.isEmpty { continue }
            
            switch page.type {

            case PageTypes.SECTION, PageTypes.KALTURA, PageTypes.YOUTUBE, PageTypes.VIMEO, PageTypes.QUIZ, PageTypes.HTML, PageTypes._DEL, PageTypes._MOVE:
                continue

            case PageTypes.IMAGE:
                
                page.src = newName
                
                if let pagesDir = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.PAGES_DIR] {

                    let oldFileName = oldName + "." + SBPLUS_XML_OBJ!.pageImgFormat
                    let newFileName = newName + "." + SBPLUS_XML_OBJ!.pageImgFormat

                    if pagesDir.fileWrappers!.contains(where: {$0.key == oldFileName}) {
                        
                        if oldFileName != newFileName {

                            if let oldFileData = pagesDir.fileWrappers![("~"+oldFileName)]?.regularFileContents {
                                
                                let newFile = FileWrapper(regularFileWithContents: oldFileData)
                                newFile.preferredFilename = newFileName
                                
                                addAssetsWrappersFile(name: newFileName, file: newFile, to: FileNames.PAGES_DIR)
                                
                            }

                        }

                    }

                }

            case PageTypes.IMAGE_AUDIO:
                
                page.src = newName
                
                if let pagesDir = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.PAGES_DIR] {

                    let oldFileName = oldName + "." + SBPLUS_XML_OBJ!.pageImgFormat
                    let newFileName = newName + "." + SBPLUS_XML_OBJ!.pageImgFormat
                    
                    if pagesDir.fileWrappers!.contains(where: {$0.key == oldFileName}) {

                        if oldFileName != newFileName {
                            
                            if let oldFileData = pagesDir.fileWrappers![("~"+oldFileName)]?.regularFileContents {
                                
                                let newFile = FileWrapper(regularFileWithContents: oldFileData)
                                newFile.preferredFilename = newFileName
                                
                                addAssetsWrappersFile(name: newFileName, file: newFile, to: FileNames.PAGES_DIR)
                                
                            }
                            
                        }

                    }

                }

                if let audiosDir = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.AUDIO_DIR] {

                    let oldFileName = oldName + "." + FileExtensions.MP3
                    let newFileName = newName + "." + FileExtensions.MP3

                    if audiosDir.fileWrappers!.contains(where: {$0.key == oldFileName}) {

                        if oldFileName != newFileName {
                            
                            if let oldFileData = audiosDir.fileWrappers![("~"+oldFileName)]?.regularFileContents {
                                
                                let newFile = FileWrapper(regularFileWithContents: oldFileData)
                                newFile.preferredFilename = newFileName
                                
                                addAssetsWrappersFile(name: newFileName, file: newFile, to: FileNames.AUDIO_DIR)

                            }

                        }

                    }

                }

                // keep the optional caption track paired with the renamed narration
                renameAssetFileOnSave(subdir: FileNames.AUDIO_DIR, oldBase: oldName, newBase: newName, ext: FileExtensions.VTT)

            case PageTypes.BUNDLE:

                page.src = newName
                
                if let pagesDir = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.PAGES_DIR] {

                    for (i, _) in page.frames.enumerated() {

                        let oldFileName = oldName + "-\(i + 1)." + SBPLUS_XML_OBJ!.pageImgFormat
                        let newFileName = newName + "-\(i + 1)." + SBPLUS_XML_OBJ!.pageImgFormat

                        if pagesDir.fileWrappers!.contains(where: {$0.key == oldFileName}) {

                            if oldFileName != newFileName {
                                
                                if let oldFileData = pagesDir.fileWrappers![("~"+oldFileName)]?.regularFileContents {
                                    
                                    let newFile = FileWrapper(regularFileWithContents: oldFileData)
                                    newFile.preferredFilename = newFileName
                                    
                                    addAssetsWrappersFile(name: newFileName, file: newFile, to: FileNames.PAGES_DIR)
                                    
                                }
                                
                            }

                        }

                    }

                }

                if let audiosDir = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.AUDIO_DIR] {

                    let oldFileName = oldName + "." + FileExtensions.MP3
                    let newFileName = newName + "." + FileExtensions.MP3

                    if audiosDir.fileWrappers!.contains(where: {$0.key == oldFileName}) {

                        if oldFileName != newFileName {
                            
                            if let oldFileData = audiosDir.fileWrappers![("~"+oldFileName)]?.regularFileContents {
                                
                                let newFile = FileWrapper(regularFileWithContents: oldFileData)
                                newFile.preferredFilename = newFileName
                                
                                addAssetsWrappersFile(name: newFileName, file: newFile, to: FileNames.AUDIO_DIR)

                            }

                        }

                    }

                }

                // keep the optional caption track paired with the renamed narration
                renameAssetFileOnSave(subdir: FileNames.AUDIO_DIR, oldBase: oldName, newBase: newName, ext: FileExtensions.VTT)

            case PageTypes.VIDEO:

                page.src = newName
                
                if let videosDir = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.VIDEO_DIR] {

                    let oldFileName = oldName + "." + FileExtensions.MP4
                    let newFileName = newName + "." + FileExtensions.MP4

                    if videosDir.fileWrappers!.contains(where: {$0.key == oldFileName}) {

                        if oldFileName != newFileName {
                            
                            if let oldFileData = videosDir.fileWrappers![("~"+oldFileName)]?.regularFileContents {
                                
                                let newFile = FileWrapper(regularFileWithContents: oldFileData)
                                newFile.preferredFilename = newFileName
                                
                                addAssetsWrappersFile(name: newFileName, file: newFile, to: FileNames.VIDEO_DIR)

                            }

                        }

                    }

                }

                // keep the optional caption track paired with the renamed video
                renameAssetFileOnSave(subdir: FileNames.VIDEO_DIR, oldBase: oldName, newBase: newName, ext: FileExtensions.VTT)

            default:
                continue
            }
            
        }
        
    }

}

