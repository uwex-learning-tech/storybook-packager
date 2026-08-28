//
//  ProjectViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/7/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
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

        // Settle collisions over what a page holds before anything else. The answer decides which
        // files are imported at all, and it has to be settled BEFORE the presentation's format is
        // allowed to move: the switch converts and rewrites every slide image in the presentation,
        // and cancelling this prompt after that would leave a fully converted presentation with
        // nothing imported into it — the one outcome the alert promises can't happen.
        var suppressedURLs: Set<URL> = []

        let conflicts = mediaConflicts(in: droppedURLs, document: document!)

        if !conflicts.isEmpty {

            guard let resolved = ImportConflictPrompt.resolve(conflicts) else { return }

            suppressedURLs = Set(resolved.flatMap { $0.suppressedURLs })

        }

        // A batch of slide images all in one format the presentation doesn't use is how an author
        // moves the presentation to that format. They can't go in one at a time — every filename
        // under assets/pages/ is built from the presentation's format — so ask once, convert the
        // slides the batch doesn't cover, and then import normally. Cancelling imports nothing.
        //
        // Only images the import could actually place get a say in what format the batch is. Every
        // import is keyed by the page number the file name ends in, so "logo.svg" names no slide and
        // is skipped further down — and offering to convert an entire presentation on the strength
        // of a file that is then not imported is how an author loses every slide image for nothing.
        let placeable = SlideImageFormat.namingAPage(droppedURLs.filter { !suppressedURLs.contains($0) })

        let currentFormat = Util.shared.canonicalImageExt(document!.getXmlObj().pageImgFormat)

        if let dropped = SlideImageFormat.uniformFormat(of: placeable), dropped != currentFormat {

            let incoming = incomingSlideImageNames(droppedURLs: placeable, format: dropped, document: document!)

            // Called off at either question — the change itself, or an image that turns out not to
            // be convertible — the batch belongs to a format the presentation didn't move to, so it
            // does not go in.
            guard document!.confirmAndSwitchPageImageFormat(to: dropped, replacing: incoming, context: .importing) else { return }

        }

        performImport(droppedURLs: droppedURLs, suppressedURLs: suppressedURLs, document: document!)

    }

    /// The names the incoming slide images are written under once the presentation is in their
    /// format, built exactly as the import itself builds them — so a slide the batch covers is
    /// matched to the file it is about to replace, and is never needlessly converted first.
    private static func incomingSlideImageNames(droppedURLs: Array<URL>, format: String, document: Document) -> Set<String> {

        var names: Set<String> = []

        let pages = document.getXmlObjPages().filter { $0.type != PageTypes.SECTION }

        for filePath in droppedURLs {

            guard Util.shared.canonicalImageExt(filePath.pathExtension) == format else { continue }

            let num = Util.shared.parseNumFromFileName(string: filePath.deletingPathExtension().lastPathComponent)

            guard !num.isEmpty else { continue }

            // Resolved the way the import resolves it, against the slide the file is for — not built
            // from the number in the file name. The caller deletes rather than converts an image it
            // is told is about to be replaced, so a name predicted here that the import then doesn't
            // write is an image destroyed for nothing.
            let positional = document.getFileNamePrefix() + num
            let parts = Util.shared.getFileNameParts(file: "\(positional).\(format)")
            let base: String

            // The import refuses a name whose page number is not one, and one past the end is
            // handled below. Predicting a name for either tells the caller an image is about to be
            // replaced when it is not, and the caller deletes rather than converts on that promise.
            guard let position = Int(parts.1), position > 0 else { continue }

            if pages.indices.contains(position - 1) {

                // The same refusal the import makes: a slide that holds no slide image is not going
                // to be given one, so nothing here is about to be replaced and the caller must not
                // be told it is.
                guard PageAssets.holdsMediaFiles(type: pages[position - 1].type) else { continue }

                base = importBase(for: pages[position - 1], positional: document.getFileNamePrefix() + "\(parts.1)", document: document)

            } else {
                // Past the end of the deck: the import creates a page here and reserves its base, so
                // predicting the bare positional name told the caller to delete an image that the
                // import then wrote somewhere else entirely.
                base = freeImportBase(proposed: document.getFileNamePrefix() + "\(parts.1)", document: document)
            }

            names.insert("\(base)\(parts.2.isEmpty ? "" : "-\(parts.2)").\(format)")

        }

        return names

    }

    // The import proper. Media conflicts are already resolved by the caller — `suppressedURLs` are
    // the dropped files that lost that decision and must not be imported.
    private static func performImport(droppedURLs: Array<URL>, suppressedURLs: Set<URL>, document: Document?) {

        // Bulk import rewrites pages and assets outside the structural-undo machinery, so any
        // transition captured earlier no longer describes the document it would restore — undoing
        // one would silently throw away the imported pages. End the undo history here.
        document!.undoManager?.removeAllActions()

        var filesToImport: Array<FileName> = []
        var captionsToImport: Array<(url: URL, pageNumber: String)> = []
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
            let fileName = "\(name + num).\(ext)"

            // Every import is keyed by the page number the file name ends in, so a name carrying no
            // digits at all ("captions.srt", "lecture.mp3") names no page and there is nothing to
            // import it onto. Report it rather than reading a page index out of an empty string.
            let filePageNumber = pageNumber(fromParsedNum: num)

            guard !filePageNumber.isEmpty else {
                skipped.append((filePath.lastPathComponent, .noPageNumber))
                continue
            }

            // A drop mixing two image formats settles no format for the presentation to move to, so
            // the images that aren't in its format are left out — with a reason, rather than the
            // wordless refusal of the whole drag this used to be.
            //
            // Asked after the page number, not before: an unnumbered image would otherwise be told
            // to re-export it in the presentation's format, and it would be skipped on the way back
            // in for the reason nobody mentioned.
            if SlideImageFormat.isSlideImage(ext), ext != Util.shared.canonicalImageExt(document!.getXmlObj().pageImgFormat) {
                skipped.append((filePath.lastPathComponent, .mismatchedImageFormat))
                continue
            }

            // Captions ride along with a page that already exists (or that another file in this same
            // drop is about to create); they never name, retype, or create a page of their own, so
            // they take a separate path and stay out of filesToImport.
            if ext == FileExtensions.VTT || ext == FileExtensions.SRT {

                // Held back until the media has landed and every slide has its final name. Written
                // here, a caption was filed under the number in its own file name — which on a deck
                // reordered since the last save is not what the slide it belongs to is called, so
                // the captions ended up on another slide or were swept as an orphan.
                captionsToImport.append((filePath, filePageNumber))

                continue

            }

            // Only the kinds a page can actually hold go on. A numbered file of any other kind used
            // to reach the page loop, where it renamed and retitled the slide and imported nothing.
            switch ext {
            case FileExtensions.MP3, FileExtensions.MP4, FileExtensions.SVG, FileExtensions.JPG, FileExtensions.JPEG, FileExtensions.PNG:
                break
            default:
                skipped.append((filePath.lastPathComponent, .unsupportedFile))
                continue
            }

            filesToImport.append(FileName(original: origrinalName, formatted: fileName, number: num, url: filePath))

        }
        
        // Sorted by page number, and by name within one number: two files claiming the same page
        // both write to the same place, so which of them wins has to be the same every run.
        filesToImport.sort(by: {
            let order = $0.number.localizedStandardCompare($1.number)
            return order == .orderedSame ? $0.originalName < $1.originalName : order == .orderedAscending
        })
        
        // create page in the page outline accordingly
        for file in filesToImport {
            
            let pages = document?.getXmlObjPages().filter{ $0.type != PageTypes.SECTION }
            var extsn = ""
            
            if let extsnRegex = try? NSRegularExpression(pattern: "(?<=\\.).*", options: NSRegularExpression.Options.caseInsensitive) {
                let matched = extsnRegex.matches(in: file.formattedName, range: NSRange(location: 0, length: file.formattedName.count))
                extsn = matched.map{ String(file.formattedName[Range($0.range, in: file.formattedName)!]) }.joined()
            }
            
            let nameParts = Util.shared.getFileNameParts(file: file.formattedName)

            // The page number is read back out of the *rebuilt* name, which carries the presentation's
            // own prefix — free text, and one containing a hyphen or trailing digits reads back as
            // something else entirely. Trapping on it crashed the whole import.
            guard let pagePosition = Int(nameParts.1), pagePosition > 0 else {
                skipped.append((file.originalName, .noPageNumber))
                continue
            }
            // Positional by design: "page03.jpg" lands on slide 3 is the contract of a bulk import.
            // The number in the file name says which slide the file is *for*; it does not say what
            // that slide's files are called.
            let lookupName = document!.getFileNamePrefix() + "\(nameParts.1)"
            
            // if file exists
            if ((pages?.indices.contains(pagePosition - 1))!) {
                
                let pageIndex = pagePosition - 1
                
                // The slide keeps the name its own files are already under, and the imported file is
                // written straight in with them. Writing it under the name in the dropped file first
                // and correcting afterwards — which is what this did — overwrote whichever slide
                // really owned that name, and the correction then deleted the evidence.
                // A slide whose src is not a base name — a widget's folder, a streaming video ID —
                // only takes one if this file is going to retype it into a slide that holds media.
                // An image doesn't, so it has nowhere to go; writing it anyway renamed the slide,
                // orphaned the widget or lost the ID, and then swept the image at the next save.
                // An HTML slide takes narration the same way the editor's Set Audio gives it one:
                // as its own reference, leaving the slide's content alone. Treating a dropped .mp3
                // as a reason to retype it threw the slide's content reference away, with no
                // question asked and no undo — the editor was fixed to stop doing exactly this.
                if pages![pageIndex].type == PageTypes.HTML && extsn == FileExtensions.MP3 {
                    
                    // Replacing narration reuses the name it is already filed under. Reserved
                    // afresh, a re-dropped file found its own predecessor in the way and became
                    // …_copy1, then _copy2, while each previous file was left to be swept.
                    let existing = pages![pageIndex].audio
                    let base = existing.isEmpty
                        ? importBase(for: pages![pageIndex], positional: lookupName, document: document!)
                        : ((existing as NSString).lastPathComponent as NSString).deletingPathExtension
                    
                    let written = writeImportedAsset(from: file.url, base: base, frame: "", ext: extsn, document: document!)
                    
                    pages![pageIndex].audio = written
                    
                    continue
                    
                }
                
                // Only a streaming slide is retyped by a dropped file, and the conflict prompt asks
                // about that one because its video ID cannot be recovered. A quiz and an HTML slide
                // hold authored work that nothing would ask about and nothing could undo — the
                // import clears the undo history before it starts — so a file numbered for one of
                // those is reported instead.
                let streaming = [PageTypes.KALTURA, PageTypes.YOUTUBE, PageTypes.VIMEO].contains(pages![pageIndex].type)
                let retypes = streaming && (extsn == FileExtensions.MP3 || extsn == FileExtensions.MP4)
                
                guard PageAssets.holdsMediaFiles(type: pages![pageIndex].type) || retypes else {
                    skipped.append((file.originalName, .slideTakesNoFileOfThisKind))
                    continue
                }

                // A video slide holds its .mp4 and its captions, and no slide image. An image
                // numbered for one used to fall through to here and be written under the slide's own
                // base name, where it did nothing: the slide stayed a video, and the next save swept
                // the image as an orphan. The only trace the drop left was the slide's title, which
                // the import rewrote on its way past — so the file looked imported and was gone.
                // The other two kinds a video slide can be sent are left alone: an .mp4 replacing
                // its video is what a bulk import is for, and an .mp3 over a slide that holds a
                // video is put to the person dropping it by ImportConflictPrompt, which opens on
                // keeping the video.
                if pages![pageIndex].type == PageTypes.VIDEO && SlideImageFormat.isSlideImage(extsn) {
                    skipped.append((file.originalName, .imageOnVideoSlide))
                    continue
                }
                
                let targetBase = importBase(for: pages![pageIndex], positional: lookupName, document: document!)
                
                let assetName = writeImportedAsset(from: file.url,
                                                   base: targetBase,
                                                   frame: nameParts.2,
                                                   ext: extsn,
                                                   document: document!)
                
                pages![pageIndex].src = targetBase
                
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
                        
                        if hasExistingSource(file: targetBase, document: document!) > -1 {
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

                autoOCRTitleIfEnabled(page: pages![pageIndex], assetName: assetName, ext: extsn, document: document!)

            } else { // if not, create new
                
                let nonSctnpages = document?.getXmlObjPages().filter{ $0.type != PageTypes.SECTION }
                let numOfPagesToAdd = (pagePosition - 1) - (nonSctnpages?.count)!

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
                
                // Reserved against the names the deck is already using: a deck whose slides were
                // renumbered but not saved can already have a slide carrying this one.
                let newBase = freeImportBase(proposed: lookupName, document: document!)
                
                writeImportedAsset(from: file.url, base: newBase, frame: nameParts.2, ext: extsn, document: document!)
                
                newPage.src = newBase
                newPage.title = "[\(file.originalName)]".pascalCaseToWords().capitalized
                
                switch extsn {
                    
                case FileExtensions.MP3:
                    
                    if hasExistingSource(file: newBase, document: document!) <= -1 {
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

                    autoOCRTitleIfEnabled(page: newPage, assetName: "\(newBase)\(nameParts.2.isEmpty ? "" : "-\(nameParts.2)").\(extsn)", ext: extsn, document: document!)

                case FileExtensions.MP4:
                    
                    newPage.type = PageTypes.VIDEO
                    document!.addSbPage(page: newPage, index: 0, refreash: false)
                    
                default:
                    break
                }
                
            }
            
        }
        
        // Now that every slide has its name, the captions can be filed beside the media they caption.
        for caption in captionsToImport {
            
            let pages = document!.getXmlObjPages().filter { $0.type != PageTypes.SECTION }
            let target = Int(caption.pageNumber).flatMap { pages.indices.contains($0 - 1) ? pages[$0 - 1] : nil }
            
            // An HTML slide has no captions: nothing in the editor offers them, and the save's
            // tidy-up has no claim form for one, so a .vtt filed beside its narration is swept on
            // the next save. Reported rather than written and quietly deleted.
            if target?.type == PageTypes.HTML {
                skipped.append((caption.url.lastPathComponent, .captionWithoutMedia))
                continue
            }
            
            let base = target?.src ?? ""
            
            // One caption track per page, so it is named for the page rather than for a frame within
            // it: a bundle's images are "…03-1", "…03-2", but its captions are "…03".
            importCaption(from: caption.url,
                          named: base.isEmpty ? "" : "\(base).\(FileExtensions.VTT)",
                          pageNumber: caption.pageNumber,
                          droppedMedia: droppedMediaByPage,
                          document: document!,
                          skipped: &skipped)
            
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
            existingPages[index + 1] = ImportConflict.ExistingPage(type: page.type,
                                                                  src: page.src,
                                                                  holdsMedia: holdsItsMedia(page: page, document: document))
        }

        return ImportConflict.detect(droppedURLs: droppedURLs, existingPages: existingPages)

    }

    // The base name an imported file should be written under for a slide that already exists.
    //
    // The slide keeps whatever its own files are called; only a slide that has no name of its own
    // takes the positional one, and then only if nothing else is using it. The number in a dropped
    // file's name says which slide the file is *for*, never what that slide's files are called.
    private static func importBase(for page: Page, positional: String, document: Document) -> String {

        // A streaming slide's src is a video ID and an HTML widget's is a folder; neither is a base
        // name a media file can be written under.
        guard PageAssets.holdsMediaFiles(type: page.type), !page.src.isEmpty else {
            return freeImportBase(proposed: positional, document: document)
        }

        return page.src

    }

    // A base name no slide in this presentation is already carrying.
    private static func freeImportBase(proposed: String, document: Document) -> String {

        let pages = document.getXmlObjPages()
        let imageFormat = document.getXmlObj().pageImgFormat

        // Judged the way Document.reserveBase judges it: a name is taken if a slide carries it, if a
        // file sits under it, or if a "~" snapshot does — a deleted slide's snapshot holds its name
        // until the next save precisely so the name is not handed straight back out. Two allocators
        // disagreeing about what "free" means is how several of the bugs in this area started.
        func taken(_ base: String) -> Bool {

            if pages.contains(where: { PageAssets.holdsMediaFiles(type: $0.type) && !$0.src.isEmpty && $0.src == base }) { return true }

            // frameCount matched to the deepest run any slide could hold under this base, so a base
            // is not called free while <base>-2 sits under it. assetBaseName passes the real count;
            // two allocators with two definitions of "free" is the shape of several bugs already.
            let frames = pages.map { $0.frames.count }.max() ?? 1

            return PageAssets.allMediaSlots(base: base, imageFormat: imageFormat, frameCount: max(frames, 1)).contains {
                document.getAssetFileWrapper(name: $0.name, at: $0.subdir) != nil
                    || document.getAssetFileWrapper(name: "~" + $0.name, at: $0.subdir) != nil
            }

        }

        guard taken(proposed) else { return proposed }

        var n = 1

        while taken("\(proposed)_copy\(n)") { n += 1 }

        return "\(proposed)_copy\(n)"

    }

    // Write one dropped file into the presentation under the slide's own name, and answer that name.
    //
    // Written once, straight to where it belongs: the file is copied from the URL it was dropped
    // from rather than read back out of the wrapper tree, so nothing is ever written to a name that
    // belongs to another slide and no intermediate copy has to be cleaned up afterwards.
    @discardableResult
    private static func writeImportedAsset(from url: URL, base: String, frame: String, ext: String, document: Document) -> String {

        let directory: String

        switch ext {
        case FileExtensions.MP3:
            directory = FileNames.AUDIO_DIR
        case FileExtensions.MP4:
            directory = FileNames.VIDEO_DIR
        case FileExtensions.SVG, FileExtensions.JPG, FileExtensions.JPEG, FileExtensions.PNG:
            directory = FileNames.PAGES_DIR
        default:
            return ""
        }

        let name = "\(base)\(frame.isEmpty ? "" : "-\(frame)").\(ext)"

        document.addAssetsWrappersFile(name: name, path: url, to: directory)

        // The stale "~" snapshot goes; a fresh one is not written. createTempFiles() makes the copy a
        // rename needs, and only where one is missing — so the import's own twin was the thing later
        // code had to defensively delete, and it doubled what a bulk import read and held.
        document.removeFileFromAssetsDir(file: "~\(name)", subDir: directory)

        return name

    }

    // Whether a slide actually holds the media its type implies — the file for the presentation's own
    // media types, and an ID for the streaming ones.
    private static func holdsItsMedia(page: Page, document: Document) -> Bool {

        guard !page.src.isEmpty else { return false }

        switch page.type {

        case PageTypes.KALTURA, PageTypes.YOUTUBE, PageTypes.VIMEO:
            return true // src is the video ID, and it is not empty

        default:

            // Every file the slide could hold, not the narration alone. A bundle with twenty frames
            // and no narration recorded yet has a great deal to lose to a dropped video — it is
            // retyped, and the frames are swept — and asking only about its .mp3 said it had nothing.
            return PageAssets.slots(type: page.type,
                                    base: page.src,
                                    imageFormat: document.getXmlObj().pageImgFormat,
                                    frameCount: page.frames.count)
                .contains { document.fileExistsInAssetsDir(fileName: $0.name, subDirName: $0.subdir, asBool: true) as? Bool ?? false }

        }

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

        // A slide that has taken no name of its own has no media either, so there is nothing here
        // for a caption to caption.
        guard !fileName.isEmpty else {
            skipped.append((filePath.lastPathComponent, .captionWithoutMedia))
            return
        }

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

        // The stale snapshot goes and no fresh one is written — the same rule writeImportedAsset
        // follows. This was the last writer of a "~" file outside the save, and createTempFiles
        // skips taking a snapshot wherever it finds one, so a twin left here is what a later reorder
        // would rename the captions from.
        document.removeFileFromAssetsDir(file: "~\(fileName)", subDir: directoryName)

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
    /// The dropped file itself. The import writes nothing until it knows which slide the file is for
    /// and what that slide's files are called, so it carries the source URL this far.
    var url: URL = URL(fileURLWithPath: "/")
    
    init(original: String, formatted: String, number: String, url: URL) {
        self.originalName = original
        self.formattedName = formatted
        self.number = number
        self.url = url
    }
    
}
