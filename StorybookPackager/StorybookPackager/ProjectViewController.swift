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
    var expectedExt = [FileExtensions.MP3, FileExtensions.MP4]
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
        var filesToImport: Array<FileName> = []
        
        // add dropped files; replace if exist, create new if not
        for url in urls {
            
            let filePath = isString ? URL(fileURLWithPath: url as! String) : url as! URL
            let origrinalName = filePath.deletingPathExtension().lastPathComponent
            let name = document!.getFileNamePrefix()
            let num = Util.shared.parseNumFromFileName(string: origrinalName);
            let ext = filePath.pathExtension
            var directoryName = ""
            let fileName = "\(name + num).\(ext)"
            
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
