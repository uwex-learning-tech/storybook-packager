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
    private var numOfSelected: Int = 0
    private var forUpdating: Bool = false
    
    @IBOutlet weak var pageDetailsScroller: NSScrollView!
    @IBOutlet weak var pageDetailsView: NSCollectionView!
    @IBOutlet weak var pageCollectionScroller: NSScrollView!
    @IBOutlet weak var pageCollectionView: NSCollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do view setup here.
        pageDetailsScroller.scrollerStyle = .overlay
        pageCollectionScroller.scrollerStyle = .overlay
        
//        pageDetailsView.delegate = self
//        pageCollectionView.delegate = self
        
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
            
            let index = indexPath.item
            
            if (self.pages![index].type != "section") {
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageViewItem"), for: indexPath) as! PageViewItem
                
                item.typeLbl.stringValue = self.pages![index].type.uppercased().replacingOccurrences(of: "-", with: " & ")
                item.countLbl.stringValue = "\(self.pages![index].num + 1)"
                item.titleLbl.stringValue = self.pages![index].title
                
                return item
                
            } else {
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageSectionItem"), for: indexPath) as! PageSectionItem
                
                item.titleLbl.stringValue = self.pages![index].title
                
                if (self.pages![index].title.isEmpty) {
                    item.titleLbl.stringValue = "Section \(self.pages![index].num + 1)"
                } else {
                    item.titleLbl.stringValue = self.pages![index].title
                }
                
                return item
                
            }
            
        } else {
            
            let page = self.pages![document!.currentPageIndex.item]
            
            switch page.type {
                
            case "section":
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SectionViewItem"), for: indexPath) as! SectionViewItem
                
                if (page.title.isEmpty) {
                    item.titleTxtfld.stringValue = "Section \(page.num)"
                } else {
                    item.titleTxtfld.stringValue = page.title
                }
                
                return item
                
            case "kaltura":
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "KalturaViewItem"), for: indexPath) as! KalturaViewItem
                
                item.titleTxtfld.stringValue = page.title
                item.entryIdTxtfld.stringValue = page.src
                item.notesTxtvw.string = page.notes
                
                return item
                
            case "image":
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ImageViewItem"), for: indexPath) as! ImageViewItem
                
                item.titleTxtfld.stringValue = page.title
                item.imgSrc.stringValue = "\(page.src).\(self.document!.getXmlObj().pageImgFormat)"
                item.notesTxtvw.string = page.notes
                
                return item
                
            case "image-audio":
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ImageAudioViewItem"), for: indexPath) as! ImageAudioViewItem
                
                item.titleTxtfld.stringValue = page.title
                item.imgSrcTxtfld.stringValue = "\(page.src).\(self.document!.getXmlObj().pageImgFormat)"
                item.audioSrcTxtfld.stringValue = page.src + ".mp3"
                item.notesTxtvw.string = page.notes
                
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
            
            let page = self.pages![document!.currentPageIndex.item]
            var pageHeight = pageDetailsView.bounds.height
            
            switch page.type {

            case "section":
                pageHeight = SectionViewItem().view.bounds.height
                break;
            case "kaltura":
                pageHeight = KalturaViewItem().view.bounds.height
                break;
            case "image":
                pageHeight = ImageViewItem().view.bounds.height
                break;
            case "image-audio":
                pageHeight = ImageAudioViewItem().view.bounds.height
                break;
            default:
                pageHeight = pageDetailsView.bounds.height

            }
            
            return CGSize(width: pageDetailsView.bounds.width, height: pageHeight)
            
        }
        
    }
    
    // unselect page cells
    func collectionView(_ collectionView: NSCollectionView, shouldDeselectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        
        if (!forUpdating) {
            
            document?.currentPageIndex = IndexPath(item: 0, section: 0)
            numOfSelected = 0
            pageDetailsView.reloadData()
            
        }
        
        forUpdating = false

        return indexPaths
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        
        updatePageDetailsView(indexPaths: indexPaths)
        
    }
    
    func updatePageDetailsView(indexPaths: Set<IndexPath>) {
        document?.currentPageIndex = indexPaths.first!
        numOfSelected = indexPaths.count
        pageDetailsView.reloadData()
    }
    
    func updatePages() {
    
        // reset
        pages = document!.getXmlObj().getSectionAsPages()
        
        // refreash
        forUpdating = true
        pageCollectionView.deselectAll(self)
        pageCollectionView.reloadItems(at: [document!.currentPageIndex])
        pageCollectionView.selectItems(at: [document!.currentPageIndex], scrollPosition: .centeredVertically)
        
    }
    
    @IBAction func addPage(_ sender: NSButton) {
        
        // add
        let page = Page()
        
        page.title = "Untitled"
        page.type = "image-audio"
        
        document?.getXmlObj().sections.last?.addPage(page: page)
        document?.updateChangeCount(.changeDone)
        
        // refreash
        refreshView()
        
    }
    
    @IBAction func addSection(_ sender: NSButton) {
        
        // add
        let section = Section()
        
        document?.getXmlObj().addSection(section: section)
        document?.updateChangeCount(.changeDone)
        
        // refreash
        refreshView()
        
    }
    
    func refreshView() {
        
        pages = document!.getXmlObj().getSectionAsPages()
        
        pageCollectionView.deselectAll(self)
        pageCollectionView.reloadData()
        pageCollectionView.selectItems(at: [IndexPath(item: pages!.count-1, section: 0)], scrollPosition: .centeredVertically)
        updatePageDetailsView(indexPaths: [IndexPath(item: pages!.count-1, section: 0)])
        
    }
    
}
