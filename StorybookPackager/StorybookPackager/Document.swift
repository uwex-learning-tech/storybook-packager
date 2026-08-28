//
//  Document.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
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

    // Set when opening the document rewrote something on its behalf (renamed downloadables, folded
    // a JPEG page image format down to JPG) and the result needs writing back to disk.
    private var needsPostOpenSave = false

    // Set while a save runs with another sheet already on the window; see save(to:ofType:for:).
    private var forceSynchronousWrite = false

    // True from the moment a save begins until its completion handler runs. The asynchronous write
    // walks and serializes DOC_WRAPPER on a background thread, and the progress sheet that makes
    // that safe is window-modal: it blocks the document window, but not the main menu bar. Menu
    // commands that mutate the wrapper tree therefore have to check this themselves — see
    // AppDelegate.validateMenuItem(_:).
    private(set) var isSaving = false

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
        
        // Only when the document hasn't already told us its own. read(from:ofType:) derives the
        // prefix from the names the presentation's slides actually carry, and NSDocument calls this
        // afterwards — so overwriting it here made that scan dead code, and opening a deck authored
        // as "sb01…" on a machine set to "page" renamed every asset in it on the next save.
        if fileNamePrefix == nil {
            fileNamePrefix = UserDefaults.standard.string(forKey: Preferences.ASSET_FILE_NAME) ?? "page"
        }
        
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
        
        conformPageImageFormat()
        
        checkForDownloadableFiles( fileWrapper: DOC_WRAPPER! )
        
        scheduleAfterOpenSave()
        
    }
    
    // Write back changes the app made to the document on its own behalf while opening it. A document
    // with no fileURL (one restored from an autosaved draft) has nowhere to be written yet; it picks
    // these up on the next real save instead.
    private func scheduleAfterOpenSave() {
        
        guard needsPostOpenSave, self.fileURL != nil else { return }
        
        needsPostOpenSave = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // This save is a side effect of opening the document, not something the user asked
            // for; a year-less presentation must not be interrogated about its release year the
            // moment it opens. The next explicit save still prompts.
            self.skipReleaseYearPrompt = true
            self.save( nil )
        }
        
    }
    
    // ".jpeg" and ".jpg" are the same format, so the packager only ever works in ".jpg". A document
    // authored back when the page image type could be set to JPEG is folded down on open: the format
    // is rewritten and every slide in assets/pages/ is renamed to match, which keeps it readable by
    // an editor that no longer offers the JPEG spelling anywhere. Bundle frames are covered too —
    // they live in the same directory and carry the same extension.
    private func conformPageImageFormat() {
        
        guard let xmlObj = SBPLUS_XML_OBJ else { return }
        
        let current = xmlObj.pageImgFormat
        let canonical = Util.shared.canonicalImageExt(current)
        
        guard current != canonical else { return }
        
        xmlObj.pageImgFormat = canonical
        
        let pages = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.PAGES_DIR]?.fileWrappers
        
        for (name, file) in pages ?? [:] {
            
            guard file.isRegularFile else { continue }
            guard (name as NSString).pathExtension.lowercased() == current else { continue }
            guard let bytes = file.regularFileContents else { continue }
            
            let renamed = (name as NSString).deletingPathExtension + "." + canonical
            
            writeAssetBytes(subdir: FileNames.PAGES_DIR, name: renamed, bytes: bytes)
            removeFileFromAssetsDir(file: name, subDir: FileNames.PAGES_DIR)
            
        }
        
        needsPostOpenSave = true
        
    }
    
    /// The raw file names in assets/pages/ that belong to slides — bundle frames included, and the
    /// "~"-prefixed shadow copies excluded. What a format change has to account for, and the list
    /// SlideImageFormat.plan partitions.
    public func pageImageAssetNames() -> Array<String> {
        
        let pages = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.PAGES_DIR]?.fileWrappers ?? [:]
        
        // importFiles() writes a "~" copy beside every asset it imports, and those live in the
        // wrapper until the next save's cleanSweep trashes them. They are not slides: counting them
        // would list names the author has never seen among the images a switch is about to lose,
        // and would spend a conversion on a throwaway file for every slide in the presentation.
        return pages.filter { $0.value.isRegularFile && !$0.key.hasPrefix("~") }.map { $0.key }
        
    }
    
    // Ask, then move: the whole sequence, which is the same for every way in — a batch dropped on
    // the page list, one image chosen through Set Image, and File ▸ Convert Slide Images…. They
    // differ only in what they do afterwards and in how the question is worded, so they share this
    // rather than each assembling a plan of their own.
    @discardableResult
    public func confirmAndSwitchPageImageFormat(to newFormat: String,
                                                replacing: Set<String> = [],
                                                context: SlideImageFormatSwitchPrompt.Context) -> Bool {
        
        let current = Util.shared.canonicalImageExt(getXmlObj().pageImgFormat)
        
        guard current != Util.shared.canonicalImageExt(newFormat) else { return false }
        
        let plan = SlideImageFormat.plan(from: current,
                                         to: newFormat,
                                         existingAssetNames: pageImageAssetNames(),
                                         replacedBy: replacing)
        
        guard SlideImageFormatSwitchPrompt.confirm(plan, context: context) else { return false }
        
        return switchPageImageFormat(to: newFormat, replacing: replacing, context: context)
        
    }
    
    // Move the whole presentation to another slide image format, bringing the images it already
    // holds with it. The format is half of every filename under assets/pages/, so changing it on its
    // own leaves every existing slide image orphaned and cleanSweep trashes the lot on the next
    // save — which is exactly what Properties used to do.
    //
    // Synchronous, start to finish, in one turn of the main run loop. Every conversion is an
    // in-memory re-encode between two raster formats, so nothing here yields — which is what makes
    // the whole operation safe rather than any flag: a save cannot arrive in the middle of something
    // that never gives the run loop a chance to deliver one. An earlier version rasterized SVG
    // through an off-screen web view, could not avoid being asynchronous, and needed a progress
    // sheet plus two queues of deferred saves to hold the gap open safely. It still didn't, quite.
    // See SlideImageFormat.Conversion for why that direction is now refused instead.
    //
    // `replacing` names the files an import is about to write; those are removed rather than
    // converted, because converting a slide that is about to be overwritten is wasted work.
    //
    // Returns whether the switch happened: a caller that meant to import on the back of it must not
    // import into a format the presentation didn't move to.
    @discardableResult
    public func switchPageImageFormat(to newFormat: String,
                                      replacing: Set<String> = [],
                                      context: SlideImageFormatSwitchPrompt.Context = .changingTheSetting) -> Bool {
        
        guard let xmlObj = SBPLUS_XML_OBJ else { return false }
        
        let current = Util.shared.canonicalImageExt(xmlObj.pageImgFormat)
        let target = Util.shared.canonicalImageExt(newFormat)
        
        guard current != target else { return false }
        
        let incoming = SlideImageFormat.baseNames(of: replacing)
        let conversion = SlideImageFormat.conversion(from: current, to: target)
        let pages = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[FileNames.PAGES_DIR]?.fileWrappers ?? [:]
        
        // Read the wrappers as they stand. Nothing is written or removed in this pass.
        var toConvert: Array<(name: String, bytes: Data)> = []
        var toRemove: Array<String> = []
        var failed: Array<String> = []
        
        for name in pageImageAssetNames().sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
            
            guard let file = pages[name], file.isRegularFile else { continue }
            guard Util.shared.sameImageFormat((name as NSString).pathExtension, current) else { continue }
            
            // The batch is about to write over this slide, so converting it is wasted work.
            if incoming.contains(SlideImageFormat.baseKey(name)) {
                toRemove.append(name)
                continue
            }
            
            // Nothing the packager can do carries this image across, and the question that got here
            // has already named it as one the presentation is about to lose.
            if conversion == .impossible {
                toRemove.append(name)
                continue
            }
            
            // A file whose bytes won't load is a failure like any other, not a quiet removal: it
            // was counted among the images the alert promised to convert, so it has to be named
            // before it goes.
            guard let bytes = file.regularFileContents else {
                failed.append(name)
                continue
            }
            
            toConvert.append((name, bytes))
            
        }
        
        var converted: [String: Data] = [:]
        
        for file in toConvert {
            
            if let bytes = SlideImageConverter.transcode(file.bytes, to: target) {
                converted[file.name] = bytes
            } else {
                failed.append(file.name)
            }
            
        }
        
        // Nothing has been written yet, so this is still a real choice.
        guard failed.isEmpty
                || SlideImageFormatSwitchPrompt.confirmFailures(failed, from: current, to: target, context: context) else { return false }
        
        commitPageImageFormat(target, converted: converted, removing: toRemove + failed)
        
        return true
        
    }
    
    // The one place a format change actually lands. Everything before this only decided.
    private func commitPageImageFormat(_ target: String, converted: [String: Data], removing: Array<String>) {
        
        guard let xmlObj = SBPLUS_XML_OBJ else { return }
        
        for (name, bytes) in converted {
            let renamed = (name as NSString).deletingPathExtension + "." + target
            writeAssetBytes(subdir: FileNames.PAGES_DIR, name: renamed, bytes: bytes)
        }
        
        for name in converted.keys {
            removeFileFromAssetsDir(file: name, subDir: FileNames.PAGES_DIR)
        }
        
        for name in removing {
            removeFileFromAssetsDir(file: name, subDir: FileNames.PAGES_DIR)
        }
        
        // The "~" snapshot beside a slide holds its pre-rename bytes for syncAssetNames. Left
        // behind, it still holds the OLD format's bytes, and createTempFiles skips making a fresh
        // one because a "~" copy already exists — so a save after two opposite switches would
        // rename a slide from artwork the presentation no longer uses.
        for name in Set(converted.keys).union(removing) {
            removeFileFromAssetsDir(file: "~" + name, subDir: FileNames.PAGES_DIR)
        }
        
        // Every read path builds its filenames from the format, so it moves with the files.
        xmlObj.pageImgFormat = target
        
        // Structural undo transitions hold FileWrapper references keyed by file name, and every one
        // of those names carries the old extension — undoing a page delete across a switch would
        // re-attach a file the presentation can no longer read, and the next save would sweep it.
        // Bulk import ends the undo history for the same reason, as does every save.
        //
        // Only when files actually moved. A presentation holding no images in the old format has
        // nothing for a stale transition to point at, and it is not asked about the change either —
        // silently dropping its undo history would be a side effect of answering no question.
        if !converted.isEmpty || !removing.isEmpty {
            undoManager?.removeAllActions()
        }
        
        updateChangeCount(.changeDone)
        
        // Until this, the outline is still drawing thumbnails of files that no longer exist and
        // marks nothing against a slide whose image didn't survive the change. Reloading the
        // outline re-selects the current row, which redraws the slide editor too.
        NotificationCenter.default.post(name: Notification.Name("reloadPageOutline"), object: self, userInfo: ["selectLast": false])
        
    }
    
    func checkForDownloadableFiles(fileWrapper: FileWrapper) {
        
        guard let fileWrappers = fileWrapper.fileWrappers else { return }

        // A document restored from an autosaved draft has no fileURL yet, so there is no document
        // name to rename the bundled downloadables to. They get renamed on the next real save.
        guard let fileURL = self.fileURL else { return }

        let docName: String = fileURL.deletingPathExtension().lastPathComponent

        // A transcript is one file. If the presentation already has one, a stray .html or .pdf at
        // the root is somebody else's file and is left where it is rather than adopted as a second.
        var heldTranscript = Downloadable.transcriptExtension(inRootNames: Array(fileWrappers.keys),
                                                              documentName: docName)
        
        // Sorted, so a package holding more than one candidate adopts the same one every time it
        // is opened rather than whichever the dictionary happened to hand over first.
        for name in fileWrappers.keys.sorted() {

            guard let file = fileWrappers[name] else { continue }

            guard file.isRegularFile, let filename = file.filename else { continue }

            // index.html is the presentation itself, not something to download — and now that a
            // transcript can be a web page, it ends in a downloadable extension. Without this it
            // would be renamed to the document's name and the package would no longer open.
            guard Downloadable.isDownloadable(rootFileName: filename) else { continue }

            let ext = (filename as NSString).pathExtension.lowercased()
            let named = Downloadable.fileName(documentName: docName, ext: ext)

            guard filename != named, let contents = file.regularFileContents else { continue }

            // The name is already taken — by the real transcript, or by a stray this same loop
            // adopted a moment ago. Read from the live tree: `fileWrappers` is a dictionary copy
            // and never sees what the loop itself added. Renaming onto it would land as "MyDoc-1.pdf", which nothing
            // ever looks for and which every later open would rename again.
            guard fileWrapper.fileWrappers?[named] == nil else { continue }

            if Downloadable.isTranscript(ext) {

                // A presentation named "index" has no name left for a web transcript to take.
                guard Downloadable.canName(transcript: ext, documentName: docName) else { continue }

                // One transcript. Whichever form is already here wins, and the first stray adopted
                // wins over the next — otherwise a package holding two strays of different forms
                // comes out of open holding two transcripts, permanently.
                if let held = heldTranscript, held != ext { continue }

                heldTranscript = ext

            }

            let renamed = FileWrapper(regularFileWithContents: contents)
            renamed.preferredFilename = named

            fileWrapper.addFileWrapper(renamed)
            fileWrapper.removeFileWrapper(file)

            needsPostOpenSave = true

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
        
        // Before syncAssetNames(), which force-unwraps the model: a document that has never been
        // touched has none until something asks for one.
        try seedModelIfNeeded()

        // create asset directory folder if it does not exist
        if (fileWrappers?[FileNames.ASSET_DIR] == nil) {

            let assetsFolder = FileWrapper(directoryWithFileWrappers: [:])
            assetsFolder.preferredFilename = FileNames.ASSET_DIR

            DOC_WRAPPER?.addFileWrapper(assetsFolder)

        } // end filewrapper in asset directory

        // clean
        syncAssetNames()

        // The XML is serialised only now, after syncAssetNames() has renamed the assets and rewritten
        // every page's src to match. Written before that, it named the files the pages held at the
        // *last* save: a reordered slide landed in the package as sbplus.xml saying "page02" beside a
        // file called page03.jpg, and only a second save put the two back together.
        try writeXmlWrapper()

        removeRootDirFile(file: ".DS_Store")
        cleanSweep(filewrapper: DOC_WRAPPER!)
        emptyTrash()
        
        return DOC_WRAPPER!
        
    }
    
    // Give the document a model if it has none at all.
    //
    // An empty presentation is seeded only in that case. A document being saved for the first time
    // has no assets/ wrapper yet but *does* have a model — one that may carry settings collected
    // moments earlier, such as the release year from the save gate below. Reseeding it from
    // emptyXML() at that point silently discarded them.
    // Throws rather than carrying on without one: everything after it in the save path — starting
    // with syncAssetNames() — takes the model as given, and a save that cannot produce one should
    // fail the way it always has rather than trap.
    private func seedModelIfNeeded() throws {

        guard SBPLUS_XML_OBJ == nil else { return }

        SBPLUS_XML_DOC = formatXML(doc: try XMLDocument(xmlString: emptyXML(), options: XML_OPTIONS))
        SBPLUS_XML_OBJ = xmlToObj(doc: SBPLUS_XML_DOC!)
        SBPLUS_XML_PAGES = SBPLUS_XML_OBJ?.getSectionAsPages()

    }

    // Serialize the in-memory presentation into assets/sbplus.xml, replacing whatever is there.
    // Called from fileWrapper(ofType:) *after* syncAssetNames(), so the names it writes are the
    // names the files in the package actually have.
    private func writeXmlWrapper() throws {

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

        // Looked up fresh rather than reused from fileWrapper(ofType:): on a first save the assets
        // directory is created after that local was captured, and the stale copy has no assets/ in it.
        guard let assets = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR],
              let data = SBPLUS_XML_DOC?.xmlData else {

            // Thrown, not shrugged off: returning here would let the save report success having
            // written no sbplus.xml at all, and the package would reopen as an empty presentation.
            throw NSError(domain: "edu.uwex.media.StorybookPackager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "The presentation could not be written.",
                NSLocalizedRecoverySuggestionErrorKey: "Its contents could not be prepared for saving. Try again, and if this keeps happening, save a copy under a new name."
            ])

        }

        // Removed first, not overwritten: addRegularFile(withContents:preferredFilename:)
        // disambiguates a name already in use, and would leave sbplus-1.xml beside the real one.
        if let existing = assets.fileWrappers?[FileNames.XML_FILE] {
            assets.removeFileWrapper(existing)
        }

        assets.addRegularFile(withContents: data, preferredFilename: FileNames.XML_FILE)

    }

    // Allow the heavy part of a save — writing every asset's bytes to disk — to run on a background
    // queue so the app no longer beachballs during saves of asset-heavy presentations. NSDocument
    // blocks the main thread only until fileWrapper(ofType:) has snapshotted the model, then writes
    // off the main thread. We gate this on having a visible window because the progress sheet shown
    // in save(to:ofType:for:completionHandler:) is what prevents the user from mutating the document
    // mid-write; without it, asynchronous writing would race the background writer.
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        return !forceSynchronousWrite && windowForSheet?.isVisible == true
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

        // Every save runs syncAssetNames(), which renames the asset files positionally and rewrites
        // page.src across the whole document, and cleanSweep(), which deletes the now-orphaned
        // files. Structural-undo transitions captured before the save reference the pre-rename
        // names and wrappers, so undoing across a save would re-pair pages with the wrong assets —
        // and the following save would then permanently delete the mispaired bytes. The undo
        // history therefore ends at each successful save.
        let clearUndoAndFinish: (Error?) -> Void = { error in
            self.isSaving = false
            if error == nil { self.undoManager?.removeAllActions() }
            completionHandler(error)
        }

        isSaving = true

        guard let host = windowForSheet, host.isVisible else {
            super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: clearUndoAndFinish)
            return
        }

        // The progress sheet is the whole safety argument for writing asynchronously: it blocks the
        // document window so nothing can mutate the wrapper tree while the writer thread walks it.
        // A window can only show one sheet, so when another is already up — the Files dialog, which
        // saves the moment a download is set or removed — beginSheet quietly queues ours, the
        // window stays live, and the race is real. Write on the main thread instead.
        if host.attachedSheet != nil {

            forceSynchronousWrite = true

            super.save(to: url, ofType: typeName, for: saveOperation) { error in
                self.forceSynchronousWrite = false
                clearUndoAndFinish(error)
            }

            return

        }

        saveProgressSheet.begin(on: host, message: "Saving “\(displayName ?? "Presentation")”…")

        // Defer one runloop turn so the sheet actually paints before fileWrapper(ofType:) briefly
        // blocks the main thread to snapshot the model.
        DispatchQueue.main.async {
            super.save(to: url, ofType: typeName, for: saveOperation) { error in
                self.saveProgressSheet.end()
                clearUndoAndFinish(error)
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
        runModalSavePanel(for: .saveAsOperation, delegate: self, didSave: #selector(self.didSaveAs(_:didSave:contextInfo:)), contextInfo: nil)
    }
    
    // AppKit calls this whether the panel was accepted or cancelled — taking the arguments it
    // actually passes is what makes the difference visible. Cancelled, this used to run anyway and
    // rename every root file onto its own name, which is the collision handled below.
    @objc private func didSaveAs(_ document: NSDocument, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {

        guard didSave, let savedAsName = self.fileURL?.deletingPathExtension().lastPathComponent, previousDocName != nil else { return }
        
        // Every root file is named for the document, so a Save As has to carry them all across —
        // including a transcript, whichever form it is in.
        var strandedTranscript = false

        for ext in Downloadable.allExtensions {

            let previousName = Downloadable.fileName(documentName: previousDocName!, ext: ext)

            // A presentation named "index" has no web transcript — that name is the player, and
            // carrying it across would copy the player into the new package as a bogus transcript.
            guard Downloadable.isDownloadable(rootFileName: previousName) else { continue }

            guard self.fileWrapperExistsInRoot(name: previousName),
                  let contents = DOC_WRAPPER?.fileWrappers?[previousName]?.regularFileContents,
                  let previous = DOC_WRAPPER?.fileWrappers?[previousName] else { continue }

            // Saving as "index" leaves a web transcript with no name to take. Written anyway it
            // would collide with the player and be filed as "index-1.html", which nothing looks
            // for — so it is left behind, and said out loud rather than lost quietly.
            guard !Downloadable.isTranscript(ext) || Downloadable.canName(transcript: ext, documentName: savedAsName) else {

                DOC_WRAPPER?.removeFileWrapper(previous)
                strandedTranscript = true

                continue

            }

            let newName = Downloadable.fileName(documentName: savedAsName, ext: ext)

            // Saved under the name it already has — a different folder, the same presentation.
            // Renaming it onto itself would add a second wrapper, which FileWrapper files as
            // "MyDoc-1.pdf", and then remove the original: every download lost to the player.
            guard newName != previousName else { continue }

            let file = FileWrapper(regularFileWithContents: contents)
            file.preferredFilename = newName

            // Removed first: while the old wrapper is still in place the new one cannot have the
            // name it asks for.
            DOC_WRAPPER?.removeFileWrapper(previous)
            DOC_WRAPPER?.addFileWrapper(file)

        }
        
        if strandedTranscript {

            Util.shared.showAlert(
                message: "The web transcript did not come across",
                informative: "A presentation named \u{201C}\(savedAsName)\u{201D} has no name left for a web transcript — it would have to be called \(FileNames.SB_HTML_FILE), which is the name the presentation itself uses. Rename the presentation and set its transcript again, or use a PDF.",
                style: .warning
            )

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

        // Undoable: performUndoableStructuralChange diffs the asset tree around performDeletePages,
        // so the images/audio it removes are captured and restored if the user undoes the delete.
        // The selection the delete lands on is worked out here and handed over, as every other
        // structural change does. Left to default to currentPageIndex, the snapshot captured the
        // selection from *before* the delete — so redoing a delete restored a row number the shorter
        // outline no longer has, and the reselect threw.
        let remaining = (SBPLUS_XML_PAGES?.count ?? 0) - indexes.count
        let landing = max((indexes.first ?? 0) - 1, 0)
        let selectionAfter: IndexSet = remaining > 0 ? [min(landing, remaining - 1)] : []

        performUndoableStructuralChange(actionName: "Delete", selectionAfter: selectionAfter) {
            self.performDeletePages(indexes: indexes)
        }

    }

    private func performDeletePages(indexes: IndexSet) {

        var tempPages: Array<Page> = []

        for index in indexes {

            let page = SBPLUS_XML_PAGES![index]

            // Only a slide that took a name owns files to delete. Built from an empty base, every one
            // of these names — ".jpg", "-1.jpg", ".mp3" — is the same name every *other* nameless
            // slide would build, so deleting this slide destroyed their work instead of its own.
            if !page.src.isEmpty {

                // A file this slide names but another slide names too is not this slide's to delete.
                // Two slides can carry one base — a package written by 1.9.9 stamped names onto
                // slides holding nothing, and a bulk import onto a reordered deck still can — and
                // deleting either one used to take the other's picture with it.
                let alsoNamedElsewhere = namesCarriedByOtherSlides(than: page)

                if !alsoNamedElsewhere.contains(page.src) {

                    for slot in PageAssets.slots(type: page.type,
                                                 base: page.src,
                                                 imageFormat: SBPLUS_XML_OBJ!.pageImgFormat,
                                                 frameCount: page.frames.count) {

                        removeFileFromAssetsDir(file: slot.name, subDir: slot.subdir)

                    }

                }

                // The "~" snapshots are deliberately left. cleanSweep() reaps them at the next save,
                // and until then one standing under a deleted slide's name stops that name being
                // handed straight back out — which is what makes undoing the delete able to put the
                // slide's own files back rather than find the name taken.

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
                            
                            // A slide with no name of its own keeps nothing alive. Without this it
                            // matched ".jpg" and "-1.jpg" — the files a build that named slides from
                            // an empty base left behind — and so preserved them for ever.
                            guard !$0.src.isEmpty else { return false }
                            
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
                
            case FileNames.HTML_DIR:
                
                // An HTML widget's content is a whole folder named for the slide's src. Nothing
                // reclaimed it, so every widget slide ever deleted stayed in the package for good.
                filewrapper.fileWrappers?.forEach({ (name, _) in
                    
                    if !SBPLUS_XML_PAGES!.contains(where: { $0.type == PageTypes.HTML && !$0.src.isEmpty && $0.src == name }) {
                        self.moveToTrash(file: (name, filewrapper.preferredFilename!))
                    }
                    
                })
                
            case FileNames.AUDIO_DIR:
                
                filewrapper.fileWrappers?.forEach({ (name, file) in
                    
                    if file.isRegularFile {
                        
                        if let index = name.lastIndex(of: ".") {
                            
                            if !SBPLUS_XML_PAGES!.contains(where: {
                                
                                switch $0.type {
                                    
                                case PageTypes.BUNDLE, PageTypes.IMAGE_AUDIO:
                                    
                                    // An unnamed slide matches a file called ".mp3" — a stray, not
                                    // anything a slide owns.
                                    return !$0.src.isEmpty && $0.src == name[..<index]
                                    
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
    
    /// The names of the files sitting at the root of the package — the player's index.html and
    /// whatever downloadables the presentation carries.
    public func rootFileNames() -> [String] {
        return Array(DOC_WRAPPER?.fileWrappers?.keys ?? [:].keys)
    }

    public func fileWrapperExistsInRoot(name: String) -> Bool {
        guard (DOC_WRAPPER?.fileWrappers?[name]) != nil else { return false }
        return true
    }
    
    @discardableResult
    public func addDownloadFile(name: String, url: URL) -> Bool {
        
        guard DOC_WRAPPER != nil else { return false }
        
        do {
            
            let file = try FileWrapper(url: url, options: .withoutMapping)
            file.preferredFilename = name
            
            DOC_WRAPPER?.addFileWrapper(file)

            return true
            
        } catch let error as NSError {
            NSLog(error.localizedDescription)
            return false
        }
        
    }

    /// The bytes of a file that has already been read. Callers that are replacing something read
    /// first and only then take the old one out: an unreadable file must not cost the user the
    /// transcript that was already there.
    public func addDownloadFile(name: String, data: Data) {

        guard DOC_WRAPPER != nil else { return }

        let file = FileWrapper(regularFileWithContents: data)
        file.preferredFilename = name

        DOC_WRAPPER?.addFileWrapper(file)

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
        
        // The parser walks this array assuming a section heads it, and indexes sections[-1] — a hard
        // crash, taking the unsaved presentation with it — the moment a slide comes first. That is
        // what deleting the first section header of a multi-section presentation produced. Asked of
        // the array being rebuilt rather than of numSections(), which reads the old model and still
        // counts the header that is on its way out.
        if newPages.first?.type != PageTypes.SECTION {
            
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

    // MARK: - Undo support for structural page operations
    //
    // Add, delete, duplicate, paste, and reorder all funnel through one primitive here. The whole
    // section/page model is small, so instead of writing per-operation inverse logic we snapshot the
    // model and diff the asset-wrapper tree around each change. Undo/redo then restore the captured
    // model and re-attach or detach exactly the asset files the operation added or removed — so
    // undeleting a page brings its image/audio back, and undoing a duplicate takes its copies away.
    // Content edits inside a page (title text, quiz answers, notes, colors) are intentionally out of
    // scope: those are handled by their own controls, not this structural model.

    // An immutable snapshot of the page structure plus which rows were selected.
    //
    // The snapshot is taken from the flat SBPLUS_XML_PAGES array — the array the outline and the
    // page editors actually mutate — and NOT from SBPLUS_XML_OBJ.sections. getSectionAsPages() and
    // backToSectionsPages() copy every page as they convert, so `sections` lags behind the flat
    // array until the next structural refresh or save; a snapshot taken from it would capture stale
    // content and undo would silently revert title/notes/quiz edits made since the last sync.
    private struct PageStructureSnapshot {
        let pages: [Page]
        let selection: IndexSet
    }

    // One asset file/dir that a structural change added or removed, and the assets/ subdir it lives in.
    private typealias AssetRef = (subdir: String, wrapper: FileWrapper)

    // A reversible structural change: model A <-> model B, with the assets present only in B (added by
    // the forward change) and only in A (removed by the forward change).
    private struct StructuralTransition {
        let fromModel: PageStructureSnapshot
        let toModel: PageStructureSnapshot
        let assetsInBOnly: [AssetRef]
        let assetsInAOnly: [AssetRef]
        let actionName: String
    }

    // Run `mutate` (the existing add/delete/insert/reorder work) as a single undoable step. Captures
    // the model and asset inventory before and after, registers the undo, and marks the doc dirty.
    // The caller keeps doing its own UI refresh for the forward change; undo/redo drive the UI via
    // the reloadPageOutline notification posted from performTransition(_:forward:).
    func performUndoableStructuralChange(actionName: String, selectionAfter: IndexSet? = nil, _ mutate: () -> Void) {

        let fromModel = capturePageStructure()
        let beforeAssets = assetInventory()

        mutate()

        let afterAssets = assetInventory()
        let addedKeys = Set(afterAssets.keys).subtracting(beforeAssets.keys)
        let removedKeys = Set(beforeAssets.keys).subtracting(afterAssets.keys)
        let assetsInBOnly = addedKeys.compactMap { afterAssets[$0] }
        let assetsInAOnly = removedKeys.compactMap { beforeAssets[$0] }

        let toModel = PageStructureSnapshot(pages: snapshotFlatPages(),
                                            selection: selectionAfter ?? currentPageIndex)

        // A mutate that ended up changing nothing (e.g. a paste whose payload failed to parse, or a
        // delete with an empty selection) must not leave a phantom entry on the undo stack — the
        // user would hit ⌘Z and see nothing happen while the real previous change stays in place.
        if assetsInBOnly.isEmpty && assetsInAOnly.isEmpty
            && structurallyEqual(fromModel.pages, toModel.pages) {
            return
        }

        let transition = StructuralTransition(fromModel: fromModel,
                                              toModel: toModel,
                                              assetsInBOnly: assetsInBOnly,
                                              assetsInAOnly: assetsInAOnly,
                                              actionName: actionName)

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.performTransition(transition, forward: false)
        }
        undoManager?.setActionName(actionName)
        // Forward change counting is left to the inner mutator's existing updateChangeCount(.changeDone);
        // undo/redo are counted automatically by NSDocument via the undo manager.

    }

    // Move the document to one side of a transition (forward = redo → B, !forward = undo → A),
    // registering the opposite direction so the next undo/redo alternates.
    private func performTransition(_ transition: StructuralTransition, forward: Bool) {

        undoManager?.registerUndo(withTarget: self) { doc in
            doc.performTransition(transition, forward: !forward)
        }
        undoManager?.setActionName(transition.actionName)

        let target = forward ? transition.toModel : transition.fromModel

        if forward {
            attachAssets(transition.assetsInBOnly)
            detachAssets(transition.assetsInAOnly)
        } else {
            attachAssets(transition.assetsInAOnly)
            detachAssets(transition.assetsInBOnly)
        }

        // backToSectionsPages()/getSectionAsPages() copy every page as they convert, so the
        // snapshot's Page objects are never aliased into the live tree here.
        if let obj = SBPLUS_XML_OBJ {
            obj.sections = obj.backToSectionsPages(pages: target.pages)
            SBPLUS_XML_PAGES = obj.getSectionAsPages()
        }
        currentPageIndex = target.selection

        NotificationCenter.default.post(name: Notification.Name("reloadPageOutline"), object: self)

    }

    private func capturePageStructure() -> PageStructureSnapshot {
        return PageStructureSnapshot(pages: snapshotFlatPages(), selection: currentPageIndex)
    }

    // A copy of the live flat page list, so later edits to the live pages can't rewrite a snapshot.
    // (Page.copy() shares the QuizItem reference — same as every getSectionAsPages() round trip —
    // which is acceptable because quiz content is outside the scope of structural undo.)
    private func snapshotFlatPages() -> [Page] {

        var pages = (SBPLUS_XML_PAGES ?? []).map { $0.copy() as! Page }

        // getXmlObjPages() strips the section header row from single-section documents; put one
        // back so backToSectionsPages() always has a section to file the pages under on restore.
        if !pages.contains(where: { $0.type == PageTypes.SECTION }) {
            let header = Page()
            header.type = PageTypes.SECTION
            header.title = "Untitled"
            header.number = 0
            pages.insert(header, at: 0)
        }

        return pages

    }

    // Whether two snapshots describe the same page structure. Content fields beyond the identifying
    // trio (type, src, title) are out of structural-undo scope, so they don't factor in.
    private func structurallyEqual(_ a: [Page], _ b: [Page]) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).allSatisfy { $0.type == $1.type && $0.src == $1.src && $0.title == $1.title }
    }

    // The set of asset files/dirs currently in the package, keyed "subdir/name" (top-level = "/name"),
    // each paired with its live FileWrapper. Used to diff what a change added or removed.
    private func assetInventory() -> [String: AssetRef] {

        var inventory: [String: AssetRef] = [:]

        guard let assets = DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers else { return inventory }

        for (name, wrapper) in assets {

            if wrapper.isDirectory {
                // one level down: pages/, audio/, video/, and per-page html/ folders
                for (child, childWrapper) in (wrapper.fileWrappers ?? [:]) {
                    inventory[name + "/" + child] = (subdir: name, wrapper: childWrapper)
                }
            } else {
                inventory["/" + name] = (subdir: "", wrapper: wrapper)
            }

        }

        return inventory

    }

    private func assetSubdirWrapper(_ subdir: String) -> FileWrapper? {
        if subdir.isEmpty { return DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR] }
        return DOC_WRAPPER?.fileWrappers?[FileNames.ASSET_DIR]?.fileWrappers?[subdir]
    }

    private func attachAssets(_ assets: [AssetRef]) {
        for asset in assets {
            guard let dir = assetSubdirWrapper(asset.subdir) else { continue }
            let name = asset.wrapper.preferredFilename ?? ""
            if dir.fileWrappers?[name] == nil {
                dir.addFileWrapper(asset.wrapper)
            }
        }
    }

    private func detachAssets(_ assets: [AssetRef]) {
        for asset in assets {
            guard let dir = assetSubdirWrapper(asset.subdir) else { continue }
            guard let name = asset.wrapper.preferredFilename, let existing = dir.fileWrappers?[name] else { continue }
            dir.removeFileWrapper(existing)
        }
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
    public func insertClipboardData(_ data: Data, atFlatIndex insertIndex: Int, undoActionName: String = "Paste") -> Int? {

        // Undoable: the asset diff in performUndoableStructuralChange captures the independent asset
        // copies this insert writes, so undo removes them again and redo brings them back.
        var inserted: Int? = nil
        performUndoableStructuralChange(actionName: undoActionName) {
            inserted = self.performInsertClipboardData(data, atFlatIndex: insertIndex)
        }
        return inserted

    }

    private func performInsertClipboardData(_ data: Data, atFlatIndex insertIndex: Int) -> Int? {

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

        // Carried across the batch: an incoming page is not in SBPLUS_XML_PAGES yet, so without this
        // two pasted slides proposing the same base are separated only by whether the first actually
        // wrote bytes — and a slide whose image the paste could not convert writes none.
        var adopted = namesCarriedByOtherSlides()

        for page in incoming {
            remapPage(page, payload: payload, assetMap: assetMap, dirMap: dirMap, destImgFmt: destImgFmt, adopted: &adopted)
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

        let insertedPages = incoming.filter { $0.type != PageTypes.SECTION }.count

        // Land the selection on the last inserted row (mirroring what the controller does after
        // this returns) *before* performUndoableStructuralChange captures its "after" snapshot —
        // otherwise redoing a paste/duplicate would restore the stale pre-insert selection.
        let lastRow = min(insertIndex + insertedPages - 1, getXmlObjPages().count - 1)
        currentPageIndex = lastRow >= 0 ? [lastRow] : []

        return insertedPages

    }

    // Pasted slide image bytes, in the destination presentation's format. Copying between two
    // presentations set to different formats used to write the source bytes under the destination's
    // extension unchanged — PNG bytes in a file named .svg, which nothing can read.
    //
    // SVG converts in neither direction, so a slide crossing between an SVG presentation and a
    // raster one comes in without its image — which the outline marks — rather than with bytes that
    // aren't the format their name claims.
    private func pastedPageImageBytes(_ bytes: Data, from: String, to: String) -> Data? {
        
        switch SlideImageFormat.conversion(from: from, to: to) {
        case .none:
            return bytes
        case .transcode:
            return SlideImageConverter.transcode(bytes, to: to)
        case .impossible:
            return nil
        }
        
    }
    
    // Remap one freshly-parsed page's asset references to names adopted into this document.
    private func remapPage(_ page: Page, payload: PageClipboard.Payload, assetMap: [String: Data], dirMap: [String: Data], destImgFmt: String, adopted: inout Set<String>) {

        let original = page.src

        switch page.type {

        case PageTypes.IMAGE:

            // Single image. syncAssetNames() renumbers it on save, so it must exist under page.src.
            let base = reserveBase(proposed: original, claimedByOtherSlides: adopted) { b in
                PageAssets.allMediaSlots(base: b, imageFormat: destImgFmt, frameCount: 1)
            }
            if let bytes = assetMap[FileNames.PAGES_DIR + "/" + original + "." + payload.pageImgFormat],
               let converted = pastedPageImageBytes(bytes, from: payload.pageImgFormat, to: destImgFmt) {
                writeAssetBytes(subdir: FileNames.PAGES_DIR, name: base + "." + destImgFmt, bytes: converted)
            }
            page.src = base
            adopted.insert(base)

        case PageTypes.IMAGE_AUDIO:

            // Image + narration (+ optional captions) share a base; reserve one free for all of them
            // so they stay paired when syncAssetNames() renumbers them on save.
            let base = reserveBase(proposed: original, claimedByOtherSlides: adopted) { b in
                PageAssets.allMediaSlots(base: b, imageFormat: destImgFmt, frameCount: 1)
            }
            if let bytes = assetMap[FileNames.PAGES_DIR + "/" + original + "." + payload.pageImgFormat],
               let converted = pastedPageImageBytes(bytes, from: payload.pageImgFormat, to: destImgFmt) {
                writeAssetBytes(subdir: FileNames.PAGES_DIR, name: base + "." + destImgFmt, bytes: converted)
            }
            if let bytes = assetMap[FileNames.AUDIO_DIR + "/" + original + "." + FileExtensions.MP3] {
                writeAssetBytes(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.MP3, bytes: bytes)
            }
            if let bytes = assetMap[FileNames.AUDIO_DIR + "/" + original + "." + FileExtensions.VTT] {
                writeAssetBytes(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.VTT, bytes: bytes)
            }
            page.src = base
            adopted.insert(base)

        case PageTypes.BUNDLE:

            let frameCount = max(page.frames.count, 1)
            let base = reserveBase(proposed: original, claimedByOtherSlides: adopted) { b in
                PageAssets.allMediaSlots(base: b, imageFormat: destImgFmt, frameCount: frameCount)
            }
            for i in 1...frameCount {
                if let bytes = assetMap[FileNames.PAGES_DIR + "/" + original + "-\(i)." + payload.pageImgFormat],
                   let converted = pastedPageImageBytes(bytes, from: payload.pageImgFormat, to: destImgFmt) {
                    writeAssetBytes(subdir: FileNames.PAGES_DIR, name: base + "-\(i)." + destImgFmt, bytes: converted)
                }
            }
            if let bytes = assetMap[FileNames.AUDIO_DIR + "/" + original + "." + FileExtensions.MP3] {
                writeAssetBytes(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.MP3, bytes: bytes)
            }
            if let bytes = assetMap[FileNames.AUDIO_DIR + "/" + original + "." + FileExtensions.VTT] {
                writeAssetBytes(subdir: FileNames.AUDIO_DIR, name: base + "." + FileExtensions.VTT, bytes: bytes)
            }
            page.src = base
            adopted.insert(base)

        case PageTypes.VIDEO:

            let base = reserveBase(proposed: original, claimedByOtherSlides: adopted) { b in
                PageAssets.allMediaSlots(base: b, imageFormat: destImgFmt, frameCount: 1)
            }
            if let bytes = assetMap[FileNames.VIDEO_DIR + "/" + original + "." + FileExtensions.MP4] {
                writeAssetBytes(subdir: FileNames.VIDEO_DIR, name: base + "." + FileExtensions.MP4, bytes: bytes)
            }
            if let bytes = assetMap[FileNames.VIDEO_DIR + "/" + original + "." + FileExtensions.VTT] {
                writeAssetBytes(subdir: FileNames.VIDEO_DIR, name: base + "." + FileExtensions.VTT, bytes: bytes)
            }
            page.src = base
            adopted.insert(base)

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

    // Find a base name (no extension) such that every file slot the page could occupy is free in this
    // document, preferring `proposed` and otherwise appending "_copy<N>". Keeps multi-file page types
    // (image+audio+captions, bundle frames) paired under one base.
    private func reserveBase(proposed: String, claimedByOtherSlides: Set<String> = [], filesFor: (String) -> [PageAssets.Slot]) -> String {

        func allFree(_ base: String) -> Bool {
            // A name another slide is carrying is not free, even when that slide holds no file under
            // it yet. Judged on the files alone, an emptied slide's name reads as available — and
            // handing it out a second time is how a save came to move one slide's picture onto
            // another, which is the very thing reserving a name is here to prevent.
            if claimedByOtherSlides.contains(base) { return false }
            for slot in filesFor(base) {
                if getAssetFileWrapper(name: slot.name, at: slot.subdir) != nil { return false }
                // The "~" snapshot counts as occupied too. It outlives the file it was made from —
                // the bulk import writes one beside every asset and only the next save's cleanSweep()
                // reaps them — and createTempFiles() skips making a fresh one where it finds any. A
                // name handed out with a stale twin still under it is a name the next reorder renames
                // *from the stale bytes*.
                if getAssetFileWrapper(name: "~" + slot.name, at: slot.subdir) != nil { return false }
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

    // The base name a page's files are filed under — the page's identity, not a restatement of where
    // it currently sits in the outline.
    //
    // A page that already has one keeps it. A page that has none takes one reserved free across every
    // slot any slide type could occupy, so nothing it is given now, or after a retype, can land on a
    // file belonging to another slide. Only a save renumbers it from there.
    //
    // Derived from the page's position instead, a slide inserted mid-deck was handed the name its
    // neighbour's files were still under — and setting its audio overwrote that neighbour's narration
    // while its image appeared, borrowed, on the new slide.
    //
    // `frameCount` is passed explicitly by the bundle editor: a bundle reserves its base before its
    // frames go in, so page.frames.count understates at that moment.
    public func assetBaseName(for page: Page, frameCount: Int? = nil) -> String {

        // A streaming slide's src is a video ID and an HTML slide's is a directory; neither is a base
        // name this can build files on, so a slide becoming one of ours starts from a fresh one.
        if !page.src.isEmpty && PageAssets.holdsMediaFiles(type: page.type) { return page.src }

        let proposed = Util.shared.cleanString(str: getFileNamePrefix() + Util.shared.formatPageNum(num: page.number + 1))
        let frames = frameCount ?? max(page.frames.count, 1)
        let imgFormat = getXmlObj().pageImgFormat

        return reserveBase(proposed: proposed, claimedByOtherSlides: namesCarriedByOtherSlides(than: page)) { base in
            PageAssets.allMediaSlots(base: base, imageFormat: imgFormat, frameCount: frames)
        }

    }

    // Every base name the other slides in this presentation are carrying. Read straight off
    // SBPLUS_XML_PAGES rather than through getXmlObjPages(), which drops the leading section row as
    // a side effect of being asked.
    private func namesCarriedByOtherSlides(than page: Page? = nil) -> Set<String> {

        var names: Set<String> = []

        for other in SBPLUS_XML_PAGES ?? [] where other !== page {
            if !other.src.isEmpty && PageAssets.holdsMediaFiles(type: other.type) { names.insert(other.src) }
        }

        return names

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
        let xml = sbParser.parse(xmlString: doc.xmlString)

        // SbXmlReader used to escape the three setup fields that are stored as XML attributes as it
        // read them, while StorybookXml.toString() escapes them again on the way out — so each
        // save/open cycle re-encoded the last one's output and a comma in an author name grew from
        // "&#44;" to "&#38;#44;" and on from there. That is fixed in SbXmlParser, but documents
        // written by an earlier version carry the damage in their XML, so unwind it here at the one
        // point every parse funnels through. On text that was never escaped this is a no-op, which
        // is what it becomes for every document once the repaired ones have been saved again.
        //
        // The remaining setup fields (title, subtitle, length, author profile, general info) are
        // written as CDATA and read back verbatim, so they were never affected.
        xml.setup.program = Util.shared.decodingXmlAttributeEntities(xml.setup.program)
        xml.setup.course = Util.shared.decodingXmlAttributeEntities(xml.setup.course)
        xml.setup.authorName = Util.shared.decodingXmlAttributeEntities(xml.setup.authorName)

        return xml

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
            // Unnamed. A page's base name is taken when it is first given a file, not when it is
            // created: seeded "page01" here, every page of a new presentation claimed slide one's
            // name, and a save wrote slide one's image out again under every other page's number.
            page.src = ""
            
            let pages: Array<Page> = Array(repeating: page, count: prefSettings.integer(forKey: Preferences.NUM_OF_PAGES))
            
            section.pages = pages
            
            sections.append(section)
            
        }
        
        let SBPLUS_XML_OBJ: StorybookXml = StorybookXml(
            accent: "0c3b6b",
            imgFormat: Util.shared.canonicalImageExt(prefSettings.string(forKey: Preferences.PAGE_IMG_FORMAT)!),
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

    // Carry out one planned move. Reads only the "~" snapshot taken before the pass began, so the
    // order the moves are applied in cannot matter.
    private func applyAssetSlotMove(_ move: AssetRename.Move) {

        guard move.oldFile != move.newFile else { return }

        guard move.hasSource else {

            // The slide holds nothing in this slot, so nothing may be left sitting under the name it
            // is taking: a file there belongs to whichever slide used to be at this position, and
            // cleanSweep() keeps any file matching *some* page's src — so the slide would come back
            // from the save wearing its predecessor's image or captions.
            //
            // The "~" twin is deliberately left: it is what the other moves in this pass read from,
            // and cleanSweep() reaps every one of them at the end of the save.
            removeFileFromAssetsDir(file: move.newFile, subDir: move.subdir)

            return

        }

        guard let data = getAssetFileWrapper(name: "~" + move.oldFile, at: move.subdir)?.regularFileContents else { return }

        let newFile = FileWrapper(regularFileWithContents: data)
        newFile.preferredFilename = move.newFile

        addAssetsWrappersFile(name: move.newFile, file: newFile, to: move.subdir)

    }

    // Renumber every slide's files to match the order the slides are now in.
    //
    // Planned in full first, then applied. Worked out slide by slide as it went, the pass read state
    // it was in the middle of changing: swapping two slides, the one that came first would clear the
    // name the other still had to be renamed out of. The planning itself lives in AssetRename, away
    // from the wrapper tree, so it can be tested.
    private func syncAssetNames() {

        let pages = SBPLUS_XML_PAGES?.filter{ $0.type != PageTypes.SECTION } ?? []

        let plan = AssetRename.plan(slides: pages.map { AssetRename.Slide(type: $0.type, src: $0.src, frameCount: $0.frames.count) },
                                    prefix: fileNamePrefix!,
                                    imageFormat: SBPLUS_XML_OBJ!.pageImgFormat,
                                    holdsFile: { self.getAssetFileWrapper(name: $0.name, at: $0.subdir) != nil })

        // Snapshot only the files actually being renamed (often none on a re-save): duplicating every
        // asset's bytes on every save was the main cost of saving an asset-heavy presentation.
        var needed: [String: Set<String>] = [:]

        for move in plan.moves where move.hasSource && move.oldFile != move.newFile {
            needed[move.subdir, default: []].insert(move.oldFile)
        }

        createTempFiles(renaming: needed)

        for move in plan.moves {
            applyAssetSlotMove(move)
        }

        for (index, name) in plan.names {
            pages[index].src = name
        }

    }

}

