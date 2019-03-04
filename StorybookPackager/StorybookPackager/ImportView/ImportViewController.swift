//
//  ImportViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/28/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class ImportViewController: NSViewController {

    @IBOutlet weak var importingProgress: NSProgressIndicator!
    @IBOutlet weak var statusMsg: NSTextField!
    
    var doc: Document?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        importingProgress.isHidden = true
        statusMsg.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(self.progressStarted), name: Notification.Name("importStarted"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.progressDone), name: Notification.Name("importCompleted"), object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        doc = NSDocumentController.shared.currentDocument as? Document
    }
    
    @IBAction func dismissDialog(_ sender: NSButton) {
        statusMsg.stringValue = ""
        statusMsg.isHidden = true
        self.dismiss(self)
    }
    
    @IBAction func importFilesBtn(_ sender: NSButton) {
        
        let importBrowsePanel = NSOpenPanel()
        importBrowsePanel.allowsMultipleSelection = true
        importBrowsePanel.canChooseDirectories = false
        importBrowsePanel.allowedFileTypes = [FileExtensions.MP4, FileExtensions.MP3, doc!.getXmlObj().pageImgFormat]
        
        importBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if (result == NSApplication.ModalResponse.OK) {
                ImportViewController.importFiles(urls: importBrowsePanel.urls)
            }
            
        } )
        
    }
    
    /** OBJECTIVE-C functions for notifications **/
    @objc func progressStarted(_ sender: Notification) {
        importingProgress.isHidden = false
        statusMsg.isHidden = true
        
    }
    
    @objc func progressDone(_ sender: Notification) {
        
        importingProgress.isHidden = true
        
        guard let userInfo = sender.userInfo else { return }
        
        statusMsg.isHidden = false
        
        guard let fileCount = userInfo["fileCount"] as? Int else { return }
        
        if fileCount == 1 {
            statusMsg.stringValue = "Success! \(fileCount) file imported."
        } else if fileCount > 1 {
            statusMsg.stringValue = "Success! \(fileCount) files imported."
        } else {
            statusMsg.stringValue = "Uh-ho! Importing failed."
        }
        
    }
    
    /** Static function **/
    static func importFiles<T>(urls: Array<T>, document: Document? = NSDocumentController.shared.currentDocument as? Document) {
        
        guard document != nil else { return }
        
        let argType = String(describing: type(of: urls).Element.self)
        
        guard argType == String(describing: URL.self) || argType == String(describing: String.self) else { return }
        
        NotificationCenter.default.post(name: Notification.Name("importStarted"), object: nil)
        
        let isString = argType == "String" ? true : false
        let prefSettings = UserDefaults.standard
        
        for url in urls {
            
            let filePath = isString ? URL(fileURLWithPath: url as! String) : url as! URL
            let origrinalName = filePath.deletingPathExtension().lastPathComponent
            let name = prefSettings.string(forKey: Preferences.ASSET_FILE_NAME)!
            let num = Util.shared.parseNumFromFileName(string: origrinalName);
            let ext = filePath.pathExtension
            var directoryName = ""
            let fileName = "\(name + num).\(ext)"
            
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
        
        document!.save(nil)
        NotificationCenter.default.post(name: Notification.Name("importCompleted"), object: nil, userInfo: ["fileCount": urls.count])
        
    }
    
}
