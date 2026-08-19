//
//  ProjectViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/7/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class ProjectViewController: NSViewController {
    
    @IBOutlet weak var sideView: NSView!
    @IBOutlet weak var selectPageMsg: NSBox!
    @IBOutlet weak var mainView: NSView!
    @IBOutlet weak var dragAndDropView: NSView!
    
    var currentDocument: Document?
    var expectedExt = [FileExtensions.MP3, FileExtensions.MP4, FileExtensions.VTT, FileExtensions.SRT]
    private var assetFilesController: FilesViewController?
    private var pageEditController: PageViewController?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        dragAndDropView.isHidden = true
        
        if !(pageEditController != nil ) {
            
            let pageEditStoryboard = NSStoryboard(name: NSStoryboard.Name(StoryboardNames.PAGE), bundle: nil)
            
            pageEditController = pageEditStoryboard.instantiateInitialController() as? PageViewController
            
        }
        
        if (pageEditController != nil) {
            addChild(pageEditController!)
            mainView.addSubview(pageEditController!.view)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadPageEdit), name: Notification.Name("pageSelected"), object: nil)
        
    }
    
    override func viewWillAppear() {

        super.viewWillAppear()

        currentDocument = NSDocumentController.shared.currentDocument as? Document

    }
    
    override func viewDidAppear() {
        
        super.viewDidAppear()
        
        if self.currentDocument?.hasUnautosavedChanges == nil {
            self.view.window?.close()
            //let appDlgt = NSApplication.shared.delegate as! AppDelegate
            //appDlgt.showStartupPanel()
        } else {
            openSavePanel()
        }

    }
    
    /*** IB ACTIONS ***/
    
    @IBAction func openPropertiesDialog(_ sender: NSToolbarItem) {
        self.displayPropertiesDialog()
    }
    
    @IBAction func openFilesDialog(_ sender: NSToolbarItem) {
        self.displayFilesDialog()
    }

    // Menu counterparts of the page editor's title buttons. They live here because this controller
    // is always in the key window's responder chain, while the page editor is only in it when the
    // editor itself has focus.
    @IBAction func applyTitleCaseMenuItem(_ sender: Any) {
        pageEditController?.applyTitleCase(sender)
    }

    @IBAction func guessTitleMenuItem(_ sender: Any) {
        pageEditController?.guessTitleFromImage(sender)
    }

    /*** NOTIFICATION METHODS ***/
    @objc func reloadPageEdit(_ sender: Notification) {
        
        guard let document = sender.object as? Document else { return }
        guard pageEditController != nil else { return }
        guard currentDocument != nil else { return }
        
        if document == currentDocument! {
            
            if document.currentPageIndex.isEmpty {
                
                mainView.isHidden = true
                selectPageMsg.isHidden = false
                
            } else {
                
                selectPageMsg.isHidden = true
                mainView.isHidden = false
                pageEditController!.currentDocument = document
                pageEditController!.setUIs()
                
            }
            
        }
        
    }
    
    /*** PRIVATE METHODS ***/
    
    private func openSavePanel() {
        
        if (self.currentDocument?.fileURL == nil) {
            
            let savePanel = NSSavePanel()
            
            savePanel.prompt = "Create"
            savePanel.nameFieldLabel = "Project Name:"
            savePanel.allowedFileTypes = ["sbproj"]
            savePanel.treatsFilePackagesAsDirectories = false
            savePanel.canCreateDirectories = true
            savePanel.isExtensionHidden = false
            savePanel.canSelectHiddenExtension = true
            
            savePanel.beginSheetModal(for: self.view.window!, completionHandler: { result in
                
                if result == NSApplication.ModalResponse.OK {
                    
                    guard let saveUrl = savePanel.url else { return }
                    
                    // projectLoaded is posted from docDidSave, not here: the save is asynchronous, so
                    // at this point the document has not yet built its page model and observers that
                    // read it would see nothing.
                    self.currentDocument?.save(to: saveUrl, ofType: (self.currentDocument?.fileType)!, for: NSDocument.SaveOperationType.saveOperation, delegate: self, didSave: #selector(self.docDidSave), contextInfo: nil)

                } else {
                    
                    self.view.window?.close()
                    
                }
                
            })
            
        } else {
            
            loadProject()
            
        }
        
    }
    
    private func loadProject() {
        
        updateWindowTitle(title: currentDocument!.getXmlObj().setup.title)
        NotificationCenter.default.post(name: Notification.Name("projectLoaded"), object: currentDocument!)
        
    }
    
    private func updateWindowTitle(title: String) {
        (self.view.window?.windowController as! ProjectWindowController).updateTitle(with: title)
    }
    
    private func displayPropertiesDialog() {
        
        if let propertiesDialogController = self.storyboard?.instantiateController(withIdentifier: WindowIdentifiers.PROPERTIES_DIALOG) as? PropertiesDialogController {
            
            propertiesDialogController.completionHandler = { (result) -> () in
                
                if (result.OK && !result.hasError) {
                    
                    self.updateWindowTitle(title: (self.currentDocument?.getXmlObj().setup.title)!)
                    self.dismiss(propertiesDialogController)
                    //self.currentDocument!.save(nil)
                    
                }
                
                if (result.CANCEL) {
                    self.dismiss(propertiesDialogController)
                }
                
            }
            
            self.presentAsSheet(propertiesDialogController)
            
        }
        
    }
    
    private func displayFilesDialog() {
        
        if !(assetFilesController != nil ) {
            let filesDialogStoryboard = NSStoryboard(name: NSStoryboard.Name(StoryboardNames.ASSET_FILES), bundle: nil)
            assetFilesController = filesDialogStoryboard.instantiateInitialController() as? FilesViewController
        }
        
        if (assetFilesController != nil) {
            self.presentAsSheet(assetFilesController!)
        }
        
    }
    
    /** Static function **/
    static func importFiles<T>(urls: Array<T>, document: Document? = NSDocumentController.shared.currentDocument as? Document) {

        guard document != nil else { return }

        let argType = String(describing: type(of: urls).Element.self)

        guard argType == String(describing: URL.self) || argType == String(describing: String.self) else { return }

        let isString = argType == "String" ? true : false
        let droppedURLs: Array<URL> = urls.map { isString ? URL(fileURLWithPath: $0 as! String) : $0 as! URL }

        // Settle collisions over what a page holds before touching anything: the answer decides
        // which files are imported at all, and cancelling has to leave the presentation exactly as
        // it was.
        var suppressedURLs: Set<URL> = []

        let conflicts = mediaConflicts(in: droppedURLs, document: document!)

        if !conflicts.isEmpty {

            guard let resolved = ImportConflictPrompt.resolve(conflicts) else { return }

            suppressedURLs = Set(resolved.flatMap { $0.suppressedURLs })

        }

        // Bulk import rewrites pages and assets outside the structural-undo machinery, so any
        // transition captured earlier no longer describes the document it would restore — undoing
        // one would silently throw away the imported pages. End the undo history here.
        document!.undoManager?.removeAllActions()

        var filesToImport: Array<FileName> = []
        var skipped: Array<(file: String, reason: ImportSkipReason)> = []

        // A caption file says nothing about whether the page it belongs to is audio- or video-backed,
        // so note which media extensions arrived for each page number in this same drop: a .vtt landing
        // alongside an .mp4 belongs in assets/video/, alongside an .mp3 in assets/audio/. The losing
        // side of a resolved conflict is left out, so a caption follows the media that actually won.
        var droppedMediaByPage: [String: Set<String>] = [:]

        for filePath in droppedURLs where !suppressedURLs.contains(filePath) {

            let ext = Util.shared.canonicalImageExt(filePath.pathExtension)

            guard ext == FileExtensions.MP3 || ext == FileExtensions.MP4 else { continue }

            let num = Util.shared.parseNumFromFileName(string: filePath.deletingPathExtension().lastPathComponent)
            droppedMediaByPage[pageNumber(fromParsedNum: num), default: []].insert(ext)

        }

        // add dropped files; replace if exist, create new if not
        for filePath in droppedURLs where !suppressedURLs.contains(filePath) {

            let origrinalName = filePath.deletingPathExtension().lastPathComponent
            let name = document!.getFileNamePrefix()
            let num = Util.shared.parseNumFromFileName(string: origrinalName);
            // Fold ".jpeg" down to ".jpg" (and lower-case ".JPG" and friends) so the imported slide
            // is stored under the same extension every other lookup builds from the document's page
            // image format. Kept under its own spelling it would be invisible in the editor and
            // swept as an orphan on the next save.
            let ext = Util.shared.canonicalImageExt(filePath.pathExtension)
            var directoryName = ""
            let fileName = "\(name + num).\(ext)"

            // Every import is keyed by the page number the file name ends in, so a name carrying no
            // digits at all ("captions.srt", "lecture.mp3") names no page and there is nothing to
            // import it onto. Report it rather than reading a page index out of an empty string.
            let filePageNumber = pageNumber(fromParsedNum: num)

            guard !filePageNumber.isEmpty else {
                skipped.append((filePath.lastPathComponent, .noPageNumber))
                continue
            }

            // Captions ride along with a page that already exists (or that another file in this same
            // drop is about to create); they never name, retype, or create a page of their own, so
            // they take a separate path and stay out of filesToImport.
            if ext == FileExtensions.VTT || ext == FileExtensions.SRT {

                // One caption track per page, so it is named for the page rather than for a frame
                // within it: a bundle's images are "…03-1", "…03-2", but its captions are "…03".
                importCaption(from: filePath,
                              named: "\(name + filePageNumber).\(FileExtensions.VTT)",
                              pageNumber: filePageNumber,
                              droppedMedia: droppedMediaByPage,
                              document: document!,
                              skipped: &skipped)

                continue

            }

            filesToImport.append(FileName(original: origrinalName, formatted: fileName, number: num))

            switch ext {
            case FileExtensions.MP3:
                directoryName = FileNames.AUDIO_DIR
            case FileExtensions.SVG, FileExtensions.JPG, FileExtensions.PNG, FileExtensions.JPEG:
                directoryName = FileNames.PAGES_DIR
            case FileExtensions.MP4:
                directoryName = FileNames.VIDEO_DIR
            default:
                directoryName = ""
            }

            document!.addAssetsWrappersFile(name: fileName, path: filePath, to: directoryName)
            document!.addAssetsWrappersFile(name: "~\(fileName)", path: filePath, to: directoryName)

        }
        
        // sort the files in filesToImport
        filesToImport.sort(by: { $0.number.localizedStandardCompare($1.number) == .orderedAscending })
        
        // create page in the page outline accordingly
        for file in filesToImport {
            
            let pages = document?.getXmlObjPages().filter{ $0.type != PageTypes.SECTION }
            var extsn = ""
            
            if let extsnRegex = try? NSRegularExpression(pattern: "(?<=\\.).*", options: NSRegularExpression.Options.caseInsensitive) {
                let matched = extsnRegex.matches(in: file.formattedName, range: NSRange(location: 0, length: file.formattedName.count))
                extsn = matched.map{ String(file.formattedName[Range($0.range, in: file.formattedName)!]) }.joined()
            }
            
            let nameParts = Util.shared.getFileNameParts(file: file.formattedName)
            let lookupName = document!.getFileNamePrefix() + "\(nameParts.1)"
            
            // if file exists
            if ((pages?.indices.contains(Int(nameParts.1)! - 1))!) {
                
                let pageIndex = Int(nameParts.1)! - 1
                
                pages![pageIndex].src = lookupName
                
                if pages![pageIndex].title.isEmpty || pages![pageIndex].title == "[Untitled]" {
                    pages![pageIndex].title = "[\(nameParts.0)]".pascalCaseToWords().capitalized
                }
                
                switch extsn {
                case FileExtensions.MP3:
                    
                    if pages![pageIndex].type != PageTypes.IMAGE_AUDIO && pages![pageIndex].type != PageTypes.BUNDLE {
                        pages![pageIndex].type = PageTypes.IMAGE_AUDIO
                    }
                
                case FileExtensions.SVG, FileExtensions.JPG, FileExtensions.JPEG, FileExtensions.PNG:
                    
                    if !nameParts.2.isEmpty {
                        
                        if hasExistingSource(file: lookupName, document: document!) > -1 {
                            pages![pageIndex].type = PageTypes.BUNDLE
                            if nameParts.2 == "1" {
                                pages![pageIndex].addFrame(frame: "00:00")
                            }
                        }
                        
                        if (nameParts.2 != "1") {
                            pages![pageIndex].addFrame(frame: "00:\(Util.shared.leadingZero(string: nameParts.2) )")
                        }
                        
                    }
                    
                case FileExtensions.MP4:

                    if pages![pageIndex].type != PageTypes.VIDEO {
                        pages![pageIndex].type = PageTypes.VIDEO
                    }

                default:
                    break
                }

                autoOCRTitleIfEnabled(page: pages![pageIndex], assetName: file.formattedName, ext: extsn, document: document!)

            } else { // if not, create new
                
                let nonSctnpages = document?.getXmlObjPages().filter{ $0.type != PageTypes.SECTION }
                let numOfPagesToAdd = (Int(nameParts.1)! - 1) - (nonSctnpages?.count)!

                if numOfPagesToAdd >= 1 {
                    
                    let prefSettings = UserDefaults.standard
                    
                    for _ in 0..<numOfPagesToAdd {
                        
                        let fillerPage = Page()
                        fillerPage.src = ""
                        fillerPage.title = "[Untitled]"
                        fillerPage.type = prefSettings.string(forKey: Preferences.PAGE_TYPE)!
                        document!.addSbPage(page: fillerPage, index: 0, refreash: true)
                        
                    }
                    
                }
                
                let newPage = Page()
                
                newPage.src = lookupName
                newPage.title = "[\(file.originalName)]".pascalCaseToWords().capitalized
                
                switch extsn {
                    
                case FileExtensions.MP3:
                    
                    if hasExistingSource(file: lookupName, document: document!) <= -1 {
                        newPage.type = PageTypes.IMAGE_AUDIO
                        document!.addSbPage(page: newPage, index: 0, refreash: false)
                    }
                    
                case FileExtensions.SVG, FileExtensions.JPG, FileExtensions.JPEG, FileExtensions.PNG:
                    
                    newPage.type = PageTypes.IMAGE
                    
                    if !nameParts.2.isEmpty {
                        
                        newPage.type = PageTypes.BUNDLE
                        newPage.addFrame(frame: "00:00")
                        
                    }
                    
                    document!.addSbPage(page: newPage, index: 0, refreash: false)

                    autoOCRTitleIfEnabled(page: newPage, assetName: file.formattedName, ext: extsn, document: document!)

                case FileExtensions.MP4:
                    
                    newPage.type = PageTypes.VIDEO
                    document!.addSbPage(page: newPage, index: 0, refreash: false)
                    
                default:
                    break
                }
                
            }
            
        }
        
        document!.refreshPageCollectionWithNew(pages: document!.getXmlObjPages())
        NotificationCenter.default.post(name: Notification.Name("reloadPageOutline"), object: document!, userInfo: ["selectLast": false])
        document!.updateChangeCount(.changeDone)

        if !skipped.isEmpty {

            Util.shared.showAlert(
                message: skipped.count == 1 ? "A file was not imported" : "\(skipped.count) files were not imported",
                informative: ImportSkipReason.report(skipped),
                style: .warning
            )

        }

    }

    // Adapt the document's page list to the plain lookup the conflict detector works from, keyed by
    // 1-based page position exactly as the import derives it from a dropped file name.
    private static func mediaConflicts(in droppedURLs: Array<URL>, document: Document) -> [ImportConflict] {

        let pages = document.getXmlObjPages().filter { $0.type != PageTypes.SECTION }

        var existingPages: [Int: ImportConflict.ExistingPage] = [:]

        for (index, page) in pages.enumerated() {
            existingPages[index + 1] = ImportConflict.ExistingPage(type: page.type, src: page.src)
        }

        return ImportConflict.detect(droppedURLs: droppedURLs, existingPages: existingPages)

    }

    // The number the page is keyed by, without the frame suffix parseNumFromFileName keeps.
    private static func pageNumber(fromParsedNum num: String) -> String {
        return String(num.split(separator: "-").first ?? "")
    }

    // Write a dropped .vtt/.srt into the asset directory that holds the page's media, converting
    // SubRip on the way in. A caption with nowhere to go is reported back to the caller, with the
    // reason it has nowhere to go, rather than dropped silently — filed anywhere else it would be
    // swept on the next save.
    private static func importCaption(from filePath: URL,
                                      named fileName: String,
                                      pageNumber: String,
                                      droppedMedia: [String: Set<String>],
                                      document: Document,
                                      skipped: inout Array<(file: String, reason: ImportSkipReason)>) {

        let directoryName: String

        switch captionDestination(pageNumber: pageNumber,
                                  droppedMedia: droppedMedia[pageNumber] ?? [],
                                  document: document) {

        case .directory(let name):
            directoryName = name

        case .noMedia:
            skipped.append((filePath.lastPathComponent, .captionWithoutMedia))
            return

        case .streamingSlide:
            skipped.append((filePath.lastPathComponent, .captionOnStreamingSlide))
            return

        }

        guard let data = try? SubtitleConverter.webVTTData(contentsOf: filePath) else {
            skipped.append((filePath.lastPathComponent, .unreadableCaption))
            return
        }

        let file = FileWrapper(regularFileWithContents: data)
        document.addAssetsWrappersFile(name: fileName, file: file, to: directoryName)
        document.addAssetsWrappersFile(name: "~\(fileName)", file: file, to: directoryName)

    }

    // Where a caption belongs, or why it belongs nowhere. Captions live next to the media they
    // caption — assets/audio/<src>.vtt or assets/video/<src>.vtt — so a page with no local media
    // has nowhere to put one. A streaming slide is not that case, even though both used to be
    // reported as one: it has a video, just not one this presentation holds, and its captions are
    // the host's. Filed here anyway, a caption would be swept on the next save.
    private enum CaptionDestination {
        case directory(String)
        case noMedia
        case streamingSlide
    }

    // Prefer the media arriving in this same drop — the page it belongs to may not exist yet — and
    // otherwise read the type of the page already holding that slot. Media that lost an import
    // conflict never reaches droppedMedia, so a caption follows the media that actually won.
    private static func captionDestination(pageNumber: String, droppedMedia: Set<String>, document: Document) -> CaptionDestination {

        if droppedMedia.contains(FileExtensions.MP4) { return .directory(FileNames.VIDEO_DIR) }
        if droppedMedia.contains(FileExtensions.MP3) { return .directory(FileNames.AUDIO_DIR) }

        let pages = document.getXmlObjPages().filter { $0.type != PageTypes.SECTION }

        guard let index = Int(pageNumber), pages.indices.contains(index - 1) else { return .noMedia }

        switch pages[index - 1].type {
        case PageTypes.VIDEO:
            return .directory(FileNames.VIDEO_DIR)
        case PageTypes.IMAGE_AUDIO, PageTypes.BUNDLE:
            return .directory(FileNames.AUDIO_DIR)
        case PageTypes.KALTURA, PageTypes.YOUTUBE, PageTypes.VIMEO:
            return .streamingSlide
        default:
            return .noMedia
        }

    }

    private static func autoOCRTitleIfEnabled(page: Page, assetName: String, ext: String, document: Document) {

        guard UserDefaults.standard.bool(forKey: Preferences.AUTO_OCR_TITLE) else { return }
        guard [FileExtensions.JPG, FileExtensions.JPEG, FileExtensions.PNG].contains(ext) else { return }
        guard page.type == PageTypes.IMAGE || page.type == PageTypes.IMAGE_AUDIO else { return }
        guard let data = document.getAssetFileWrapper(name: assetName, at: FileNames.PAGES_DIR)?.regularFileContents else { return }

        // importFiles calls refreshPageCollectionWithNew() synchronously right after this returns,
        // which rebuilds the whole page model via copy() and discards every Page instance in flight
        // — including `page`. OCR reliably outlasts that, so writing through the captured reference
        // would silently land on an orphaned copy. Re-resolve the live page by its stable src instead.
        let pageSrc = page.src

        SlideTitleOCR.guessTitle(from: .data(data)) { result in

            guard case .success(let raw) = result else { return }
            let title = Util.shared.cleanString(str: raw)
            guard !title.isEmpty else { return }

            let livePages = document.getXmlObjPages()

            guard let pageIndex = livePages.firstIndex(where: {
                $0.src == pageSrc && ($0.type == PageTypes.IMAGE || $0.type == PageTypes.IMAGE_AUDIO)
            }) else { return }

            let livePage = livePages[pageIndex]
            livePage.title = title

            // Name the page: the outline refreshes the row that actually changed, which need not be
            // the selected row — and after a delete-all nothing is selected at all.
            NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: document, userInfo: ["page": livePage])

            // The editor pane only shows the selected page, so leave it alone otherwise rather than
            // stomping whatever the user is typing into another page's fields.
            if document.currentPageIndex.first == pageIndex {
                NotificationCenter.default.post(name: Notification.Name("pageSelected"), object: document)
            }

            document.updateChangeCount(.changeDone)

        }

    }

    private static func hasExistingSource(file: String, document: Document) -> Int {
        
        var found: Int = -1
        
        for (index, page) in document.getXmlObjPages().enumerated() {
            
            if page.type == PageTypes.BUNDLE || page.type == PageTypes.IMAGE_AUDIO || page.type == PageTypes.IMAGE {
                
                if page.src == file {
                    found = index
                    break
                }
                
            }
            
        }
        
        return found
        
    }
    
    /*** OBJECTIVE-C FUNCTIONS ***/
    
    @objc func docDidSave(_ doc: NSDocument?, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {

        guard didSave, let document = doc as? Document else { return }

        NotificationCenter.default.post(name: Notification.Name("projectLoaded"), object: document)
        displayPropertiesDialog()

    }
    
}

extension String {
    
    func pascalCaseToWords() -> String {
        
        return unicodeScalars.reduce("") {
            
            if CharacterSet.uppercaseLetters.contains($1) {
                if $0.count > 0 {
                    return ($0 + " " + String($1))
                }
            }
            
            if CharacterSet.decimalDigits.contains($1) {
                
                if $0.count > 0 && !isDigit(set: [$0.unicodeScalars.last!]) && !isPunctuation(set: [$0.unicodeScalars.last!]) {
                    return ($0 + " " + String($1))
                }
                
            }
            
            return $0 + String($1)
            
        }
        
    }
    
    private func isDigit(set: CharacterSet) -> Bool {
        
        let digits = NSCharacterSet.decimalDigits
        return digits.isSuperset(of: set)
        
    }
    
    private func isPunctuation(set: CharacterSet) -> Bool {
        
        let punctuation = NSCharacterSet.punctuationCharacters
        return punctuation.isSuperset(of: set)
        
    }
    
}

extension ProjectViewController: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {

        switch menuItem.action {
        case #selector(applyTitleCaseMenuItem(_:)):
            return pageEditController?.canApplyTitleCase ?? false
        case #selector(guessTitleMenuItem(_:)):
            return pageEditController?.canGuessTitle ?? false
        default:
            return true
        }

    }

}

struct FileName {
    
    var originalName: String = ""
    var formattedName: String = ""
    var number: String = ""
    
    init(original: String, formatted: String, number: String) {
        self.originalName = original
        self.formattedName = formatted
        self.number = number
    }
    
}
