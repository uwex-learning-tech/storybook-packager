//
//  ProjectViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/7/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class ProjectViewController: NSViewController {
    
    @IBOutlet weak var sideView: NSView!
    @IBOutlet weak var mainView: NSView!
    
    private var document: Document?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        document = NSDocumentController.shared.currentDocument as? Document
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
                    NotificationCenter.default.post(name: Notification.Name("projectCreated"), object: nil)
                    
                } else {
                    
                    self.view.window?.close()
                    
                }
                
            })
            
        } else {
            
            updateWindowTitle(title: document!.getXmlObj().setup.title)
            NotificationCenter.default.post(name: Notification.Name("projectCreated"), object: nil)
            
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
                    
                    NotificationCenter.default.post(name: Notification.Name("reloadPageEdit"), object: nil)
                    self.dismiss(settingsDialogController)
                    
                }
                
            }
            
            self.presentAsSheet(settingsDialogController)
            
        }
        
    }
    
    private func displayFilesDialog() {
        
        if let filesDialogController = self.storyboard?.instantiateController(withIdentifier: WindowIdentifiers.FILES_DIALOG) as? FilesViewController {
            
            self.presentAsSheet(filesDialogController)
            
        }
        
    }
    
    /*** OBJECTIVE-C FUNCTIONS ***/
    
    @objc func docDidSave(_ doc: NSDocument?, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        displayPropertiesDialog()
    }
    
}
