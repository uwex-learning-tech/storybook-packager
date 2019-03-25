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
        
        if currentDocument != nil {
            expectedExt.append(currentDocument!.getXmlObj().pageImgFormat)
        }
        
    }
    
    override func viewDidAppear() {
        
        super.viewDidAppear()
        openSavePanel()

    }
    
    /*** IB ACTIONS ***/
    
    @IBAction func openPropertiesDialog(_ sender: NSToolbarItem) {
        self.displayPropertiesDialog()
    }
    
    @IBAction func openSettingsDialog(_ sender: NSToolbarItem) {
        self.displaySettingsDialog()
    }
    
    @IBAction func openFilesDialog(_ sender: NSToolbarItem) {
        self.displayFilesDialog()
    }
    
    @IBAction func openImportDialog(_ sender: NSToolbarItem) {
        
        if dragAndDropView.isHidden {
            dragAndDropView.isHidden = false
        } else {
            dragAndDropView.isHidden = true
        }
        
    }
    
    @IBAction func importFilesBtn(_ sender: NSButton) {
        
        let importBrowsePanel = NSOpenPanel()
        importBrowsePanel.allowsMultipleSelection = true
        importBrowsePanel.canChooseDirectories = false
        importBrowsePanel.allowedFileTypes = expectedExt
        
        importBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if (result == NSApplication.ModalResponse.OK) {
                ProjectViewController.importFiles(urls: importBrowsePanel.urls)
            }
            
        } )
        
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
                    
                    self.currentDocument?.save(to: saveUrl, ofType: (self.currentDocument?.fileType)!, for: NSDocument.SaveOperationType.saveOperation, delegate: self, didSave: #selector(self.docDidSave), contextInfo: nil)
                    NotificationCenter.default.post(name: Notification.Name("projectLoaded"), object: self.currentDocument!)
                    
                } else {
                    
                    self.view.window?.close()
                    
                }
                
            })
            
        } else {
            
            updateWindowTitle(title: currentDocument!.getXmlObj().setup.title)
            NotificationCenter.default.post(name: Notification.Name("projectLoaded"), object: currentDocument!)
            
        }
        
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
                    self.currentDocument!.save(nil)
                    
                }
                
                if (result.CANCEL) {
                    self.dismiss(propertiesDialogController)
                }
                
            }
            
            self.presentAsSheet(propertiesDialogController)
            
        }
        
    }
    
    private func displaySettingsDialog() {
        
        if let settingsDialogController = self.storyboard?.instantiateController(withIdentifier: WindowIdentifiers.SETTINGS_DIALOG) as? SettingsDialogController {
            
            settingsDialogController.completionHandler = { (result) -> () in
                
                if result.OK && !result.hasError {
                    
                    //NotificationCenter.default.post(name: Notification.Name("pageSelected"), object: self.currentDocument!)
                    self.dismiss(settingsDialogController)
                    
                }
                
            }
            
            self.presentAsSheet(settingsDialogController)
            
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
        var pages = document?.getXmlObjPages()
        var filesToImport: Array<String> = [];
        
        for url in urls {
            
            let filePath = isString ? URL(fileURLWithPath: url as! String) : url as! URL
            let origrinalName = filePath.deletingPathExtension().lastPathComponent
            let name = document!.getFileNamePrefix()
            let num = Util.shared.parseNumFromFileName(string: origrinalName);
            let ext = filePath.pathExtension
            var directoryName = ""
            let nameExt = name + num
            let fileName = "\(nameExt).\(ext)"
            
            filesToImport.append(fileName)
            
            switch ext {
            case FileExtensions.MP3:
                directoryName = FileNames.AUDIO_DIR
            case FileExtensions.SVG, FileExtensions.JPG, FileExtensions.PNG:
                directoryName = FileNames.PAGES_DIR
            case FileExtensions.MP4:
                directoryName = FileNames.VIDEO_DIR
            default:
                directoryName = ""
            }
            
            document!.addAssetsWrappersFile(name: fileName, path: filePath, to: directoryName)
            
        }
        
        for file in filesToImport {
            
            var extsn = ""
            var name = ""
            
            if let extsnRegex = try? NSRegularExpression(pattern: "(?<=\\.).*", options: NSRegularExpression.Options.caseInsensitive) {
                let matched = extsnRegex.matches(in: file, range: NSRange(location: 0, length: file.count))
                extsn = matched.map{ String(file[Range($0.range, in: file)!]) }.joined()
            }
            
            if let nameRegex = try? NSRegularExpression(pattern: ".*(?<=\\.)", options: NSRegularExpression.Options.caseInsensitive) {
                let matched = nameRegex.matches(in: file, range: NSRange(location: 0, length: file.count))
                name = matched.map{ String(file[Range($0.range, in: file)!]) }.joined()
                let nameArray = name.split(separator: ".")
                name = String(nameArray[0])
            }
            
            // if file exists
            if (pages?.contains(where: { $0.src == name }))! {
                
                print("file exists")
                
                let pageIndex = pages?.firstIndex(where: {$0.src == name})
                
                if pages![pageIndex!].title.isEmpty || pages![pageIndex!].title == "Untitled" {
                    pages![pageIndex!].title = "[\(name)]"
                }
                
                switch extsn {
                case FileExtensions.MP3:
                    
                    if pages![pageIndex!].type != PageTypes.IMAGE_AUDIO && pages![pageIndex!].type != PageTypes.BUNDLE {
                        pages![pageIndex!].type = PageTypes.IMAGE_AUDIO
                    }
                    
                case FileExtensions.MP4:
                    
                    if pages![pageIndex!].type != PageTypes.VIDEO {
                        pages![pageIndex!].type = PageTypes.VIDEO
                    }
                    
                default:
                    break
                }
                
            } else { // if not, create new
                
                let newPage = Page()
                
                newPage.src = name
                newPage.title = "[\(name)]"
                
                switch extsn {
                    
                case FileExtensions.MP3:
                    
                    if !hasCompanion(file: name + ".\(document!.getXmlObj().pageImgFormat)", directory: filesToImport) {
                        newPage.type = PageTypes.IMAGE_AUDIO
                        document!.addSbPage(page: newPage)
                    }
                    
                case FileExtensions.SVG, FileExtensions.JPG, FileExtensions.PNG:
                    
                    if hasCompanion(file: name + ".mp3", directory: filesToImport) {
                        newPage.type = PageTypes.IMAGE_AUDIO
                    } else {
                        newPage.type = PageTypes.IMAGE
                    }
                    
                    document!.addSbPage(page: newPage)
                    
                case FileExtensions.MP4:
                    
                    newPage.type = PageTypes.VIDEO
                    document!.addSbPage(page: newPage)
                    
                default:
                    break
                }
                
            }
            
            NotificationCenter.default.post(name: Notification.Name("reloadPageOutline"), object: document!)
            
        }
        
        document!.save(nil)
        
    }
    
    private static func hasCompanion(file:String, directory: Array<String>) -> Bool {
        
        guard directory.count > 2 else { return false }
        
        if directory.firstIndex(where: {$0 == file }) != nil { return true }
        
        return false
        
    }
    
    /*** OBJECTIVE-C FUNCTIONS ***/
    
    @objc func docDidSave(_ doc: NSDocument?, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        displayPropertiesDialog()
    }
    
}
