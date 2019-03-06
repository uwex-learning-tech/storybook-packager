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
    @IBOutlet weak var mainView: NSView!
    @IBOutlet weak var dragAndDropView: NSView!
    
    var document: Document?
    private var assetFilesController: FilesViewController?
    var expectedExt = [FileExtensions.MP3, FileExtensions.MP4]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dragAndDropView.isHidden = true
        
    }
    
    override func viewWillAppear() {
        
        super.viewWillAppear()
        
        document = NSDocumentController.shared.currentDocument as? Document
        
        if document != nil {
            expectedExt.append(document!.getXmlObj().pageImgFormat)
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
    
    /*** PRIVATE METHODS ***/
    
    private func openSavePanel() {
        
        if (self.document?.fileURL == nil) {
            
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
                    
                    self.document?.save(to: saveUrl, ofType: (self.document?.fileType)!, for: NSDocument.SaveOperationType.saveOperation, delegate: self, didSave: #selector(self.docDidSave), contextInfo: nil)
                    NotificationCenter.default.post(name: Notification.Name("projectLoaded"), object: self.document!)
                    
                } else {
                    
                    self.view.window?.close()
                    
                }
                
            })
            
        } else {
            
            updateWindowTitle(title: document!.getXmlObj().setup.title)
            NotificationCenter.default.post(name: Notification.Name("projectLoaded"), object: document!)
            
        }
        
    }
    
    private func updateWindowTitle(title: String) {
        (self.view.window?.windowController as! ProjectWindowController).updateTitle(with: title)
    }
    
    private func displayPropertiesDialog() {
        
        if let propertiesDialogController = self.storyboard?.instantiateController(withIdentifier: WindowIdentifiers.PROPERTIES_DIALOG) as? PropertiesDialogController {
            
            propertiesDialogController.completionHandler = { (result) -> () in
                
                if (result.OK && !result.hasError) {
                    
                    self.updateWindowTitle(title: (self.document?.getXmlObj().setup.title)!)
                    self.dismiss(propertiesDialogController)
                    self.document!.save(nil)
                    
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
                
                if ( (result.OK && !result.hasError) || result.CANCEL ) {
                    
                    NotificationCenter.default.post(name: Notification.Name("reloadPageEdit"), object: self.document!)
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
        let prefSettings = UserDefaults.standard
        var pages = document?.getXmlObjPages()
        var filesToImport: Array<String> = [];
        
        for url in urls {
            
            let filePath = isString ? URL(fileURLWithPath: url as! String) : url as! URL
            let origrinalName = filePath.deletingPathExtension().lastPathComponent
            let name = prefSettings.string(forKey: Preferences.ASSET_FILE_NAME)!
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
            
            if document!.fileExistsInAssetsDir(fileName: fileName, subDirName: directoryName, asBool: true) as! Bool {
                
                document!.removeFileFromAssetsDir(file: fileName, subDir: directoryName)
                document!.addAssetsWrappersFile(name: fileName, path: filePath, to: directoryName)
                
            } else {
                
                document!.addAssetsWrappersFile(name: fileName, path: filePath, to: directoryName)
                
            }
            
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
            
            if (pages?.contains(where: { $0.src == name }))! {
                
                let pageIndex = pages?.firstIndex(where: {$0.src == name})
                
                if pages![pageIndex!].title.isEmpty || pages![pageIndex!].title == "Untitled" {
                    pages![pageIndex!].title = "[\(name)]"
                }
                
                switch extsn {
                case FileExtensions.MP3:
                    
                    if pages![pageIndex!].type != PageTypes.IMAGE_AUDIO {
                        pages![pageIndex!].type = PageTypes.IMAGE_AUDIO
                    }
                    
                case FileExtensions.SVG, FileExtensions.JPG, FileExtensions.PNG:
                    
                    if (document!.fileExistsInAssetsDir(fileName: name + FileExtensions.MP3, subDirName: FileNames.AUDIO_DIR, asBool: true) as! Bool) {
                        pages![pageIndex!].type = PageTypes.IMAGE_AUDIO
                        print("exist")
                    } else {
                        pages![pageIndex!].type = PageTypes.IMAGE
                    }
                    
                case FileExtensions.MP4:
                    
                    if pages![pageIndex!].type != PageTypes.VIDEO {
                        pages![pageIndex!].type = PageTypes.VIDEO
                    }
                    
                default:
                    pages![pageIndex!].type = prefSettings.string(forKey: Preferences.PAGE_TYPE)!
                }
                
            } else {
                
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
            
        }
        
        document!.save(nil)
        NotificationCenter.default.post(name: Notification.Name("reloadPageCollection"), object: document!, userInfo: ["refreshOnly":false])
        
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
