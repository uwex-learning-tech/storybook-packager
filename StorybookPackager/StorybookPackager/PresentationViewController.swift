//
//  PresentationViewController.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit
import SbXmlParser

class PresentationViewController: NSViewController {
    
    private var document: Document?
    private var sbXml: StorybookXml?
    private var pages: Array<Page>?
    private var pageCount = 0;
    @IBOutlet weak var pageDetailsScroller: NSScrollView!
    @IBOutlet weak var pageDetailsView: NSCollectionView!
    @IBOutlet weak var pageCollectionScroller: NSScrollView!
    @IBOutlet weak var pageCollectionView: NSCollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do view setup here.
        pageDetailsScroller.scrollerStyle = .overlay
        pageCollectionScroller.scrollerStyle = .overlay
        
    }
    
    override func viewWillAppear() {
        document = NSDocumentController.shared.currentDocument as? Document
    }
    
    override func viewDidAppear() {
        
        self.openSavePanel()

    }
    
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
                    
                } else {
                    
                    self.view.window?.close()
                    
                }
                
            })
            
        } else {
            
            setFields()
            
        }
        
    }
    
    @objc func docDidSave(_ doc: NSDocument?, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        
        self.displayPropertiesDialog()
        self.setFields()
        
    }
    
    private func displayPropertiesDialog() {
        
        if let propertiesDialogController = self.storyboard?.instantiateController(withIdentifier: WindowIdentifiers.PROPERTIES_DIALOG) as? PropertiesDialogController {
            
            propertiesDialogController.completionHandler = { (result) -> () in
                
                if (result.OK) {
                    
                    var properties: Setup = Setup()
                    
                    properties.title = result.title
                    properties.subtitle = result.subtitle
                    properties.program = result.program
                    properties.course = result.courseNumber
                    properties.releaseYear = result.releaseYear
                    properties.length = result.length
                    properties.generalInfo = result.generalInfo
                    properties.authorName = result.authorName
                    properties.authorProfile = result.authorProfile
                    properties.overrideProfile = result.overrideProfile
                    
                    if (!result.hasError) {
                        self.document?.getXmlObj().setSetup(setup: properties)
                        self.document?.updateChangeCount(NSDocument.ChangeType.changeDone)
                        self.updateWindowTitle(title: result.title)
                        self.dismiss(propertiesDialogController)
                    }
                    
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
                
                if ( result.OK ) {
                    
                    let settings = self.document?.getXmlObj()
                    
                    settings!.accent = result.accentColor
                    settings!.splashImgFormat = result.splashImgType
                    settings!.pageImgFormat = result.pageImgType
                    settings!.analytics = result.analyticsOn
                    settings!.mathJax = result.mathJaxOn
                    
                    if (!result.hasError) {
                        self.document?.updateChangeCount(NSDocument.ChangeType.changeDone)
                        self.dismiss(settingsDialogController)
                    }
                    
                }
                
                if (result.CANCEL) {
                    self.dismiss(settingsDialogController)
                }
                
            }
            
            self.presentAsSheet(settingsDialogController)
            
        }
        
    }
    
    private func setFields() {
        
        self.pages = self.document?.getXmlObj().getSectionAsPages()
        self.pageDetailsScroller.isHidden = false
        
        self.updateWindowTitle(title: self.document!.getXmlObj().setup.title)
        
        self.pageCollectionView.reloadData()
        
    }
    
    private func updateWindowTitle(title: String) {
        (self.view.window?.windowController as! ProjectWindowController).updateTitle(with: title)
    }
    
    // TOOLBAR ITEM METHODS
    @IBAction func openPropertiesDialog(_ sender: NSToolbarItem) {
        self.displayPropertiesDialog()
    }
    
    @IBAction func openSettingsDialog(_ sender: NSToolbarItem) {
        self.displaySettingsDialog()
    }
    
}

extension PresentationViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            let item: PageViewItem
            let index = indexPath.item
            
            if (self.pages![index].type != "section") {
                
                item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageViewItem"), for: indexPath) as! PageViewItem
                
                self.pageCount += 1
                
                item.typeLbl.stringValue = self.pages![index].type.uppercased()
                item.countLbl.stringValue = "\(self.pageCount)"
                item.titleLbl.stringValue = self.pages![index].title
                
            } else {
                
                item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageViewItem"), for: indexPath) as! PageViewItem
                
                item.typeLbl.stringValue = self.pages![index].type.uppercased()
                item.titleLbl.stringValue = self.pages![index].title
                
            }
            
            return item
            
        } else {
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "VideoViewItem"), for: indexPath) as! VideoViewItem
            
            item.pageTitle?.stringValue = ""
            
            guard let url = URL(string: "file:///Users/ethan.lin/Desktop/GitHub/sbplus_v3/build/assets/video/smgt370_course_intro.mp4") else { return item }
            
            let player = AVPlayer(url: url)
            
            item.mediaPreview?.player = player
            
            return item
            
        }
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {

        if (collectionView.identifier!.rawValue == "pages") {
            
            guard let num = self.pages?.count else {
                return 0;
            }

            return num

        } else {

            return 1

        }

    }
    
}

extension PresentationViewController: NSCollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            
            return CGSize(width: pageCollectionView.bounds.width - 20, height: PageViewItem().view.bounds.height)
            
        } else {

            return CGSize(width: pageDetailsView.bounds.width - 20, height: VideoViewItem().view.bounds.height)
            
        }
        
    }
    
    // select page cell
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        
        guard let item = collectionView.item(at: indexPaths.first!) as? PageViewItem else {
            return
        }
        
        item.container.layer?.borderWidth = PageCell.borderWidthSelected
        item.container.layer?.borderColor = PageCell.borderColorSelected
        
    }
    
    // unselect page cells
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        
        guard let item = collectionView.item(at: indexPaths.first!) as? PageViewItem else {
            return
        }
        
        item.container.layer?.borderWidth = PageCell.borderWidth
        item.container.layer?.borderColor = PageCell.borderColor
        
    }
    
}
