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
    private var selectedPageIndex: Int?
    private var numOfSelected: Int = 0
    
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
    
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
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
        
        if ((self.document?.getXmlObj().getNumSections())! == 1) {
            self.pages!.removeFirst()
        }
        
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
            
            let index = indexPath.item
            
            if (self.pages![index].type != "section") {
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageViewItem"), for: indexPath) as! PageViewItem
                
                self.pageCount += 1
                
                item.typeLbl.stringValue = self.pages![index].type.uppercased().replacingOccurrences(of: "-", with: " & ")
                item.countLbl.stringValue = "\(self.pageCount)"
                item.titleLbl.stringValue = self.pages![index].title
                
                return item
                
            } else {
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageSectionItem"), for: indexPath) as! PageSectionItem
                
                item.titleLbl.stringValue = self.pages![index].title
                
                return item
                
            }
            
        } else {
            
            let page = self.pages![selectedPageIndex!]
            
            switch page.type {
                
            case "section":
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SectionViewItem"), for: indexPath) as! SectionViewItem
                
                item.titleTxtfld.stringValue = page.title
                
                return item
                
            case "kaltura":
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "KalturaViewItem"), for: indexPath) as! KalturaViewItem
                
                item.pageTitle?.stringValue = page.title
                item.notesTxtvw.string = page.notes
                
                guard let url = URL(string: "file:///Users/ethan.lin/Desktop/GitHub/sbplus_v3/build/assets/video/smgt370_course_intro.mp4") else { return item }
                
                let player = AVPlayer(url: url)
                
                item.mediaPreview?.player = player
                
                return item
                
            default:

                return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "EmptyViewItem"), for: indexPath) as! EmptyViewItem

            }
            
        }
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {

        if (collectionView.identifier!.rawValue == "pages") {
            
            guard let num = self.pages?.count else {
                return 0;
            }
            
            return num

        } else {

            return numOfSelected

        }

    }
    
}

extension PresentationViewController: NSCollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            let itemWidth = pageCollectionView.bounds.width - 20
            var itemHeight = PageViewItem().view.bounds.height
            
            if (self.pages![indexPath.item].type == "section") {
                
                itemHeight = PageSectionItem().view.bounds.height
                
            }
            
            return CGSize(width: itemWidth, height: itemHeight)
            
        } else {
            
            let page = self.pages![selectedPageIndex!]
            var pageHeight = pageDetailsView.bounds.height - 20
            
            switch page.type {

            case "kaltura":
                pageHeight = KalturaViewItem().view.bounds.height
                break;
            default:
                pageHeight = pageDetailsView.bounds.height - 20
                
            }
            
            return CGSize(width: pageDetailsView.bounds.width - 20, height: pageHeight)
            
        }
        
    }
    
    // select page cell
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        
        if collectionView.item(at: indexPaths.first!)?.identifier?.rawValue == "PageViewItem" {
            
            let pageItem = collectionView.item(at: indexPaths.first!) as? PageViewItem
            
            pageItem!.container.layer?.borderWidth = PageCell.borderWidthSelected
            pageItem!.container.layer?.borderColor = PageCell.borderColorSelected
            
        }
        
        if collectionView.item(at: indexPaths.first!)?.identifier?.rawValue == "PageSectionItem" {
            
            let sectionItem = collectionView.item(at: indexPaths.first!) as? PageSectionItem
            
            sectionItem!.container.layer?.borderWidth = PageCell.borderWidthSelected
            sectionItem!.container.layer?.borderColor = PageCell.borderColorSelected
            
        }
        
        selectedPageIndex = indexPaths.first!.item
        numOfSelected = indexPaths.count
        pageDetailsView.reloadData()
        
    }
    
    // unselect page cells
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        
        if collectionView.item(at: indexPaths.first!)?.identifier?.rawValue == "PageViewItem" {
            
            let pageItem = collectionView.item(at: indexPaths.first!) as? PageViewItem
            
            pageItem!.container.layer?.borderWidth = PageCell.borderWidth
            pageItem!.container.layer?.borderColor = PageCell.borderColor
            
        }
        
        if collectionView.item(at: indexPaths.first!)?.identifier?.rawValue == "PageSectionItem" {
            
            let sectionItem = collectionView.item(at: indexPaths.first!) as? PageSectionItem
            
            sectionItem!.container.layer?.borderWidth = PageCell.borderWidth
            sectionItem!.container.layer?.borderColor = PageCell.borderColor
            
        }
        
    }
    
}
