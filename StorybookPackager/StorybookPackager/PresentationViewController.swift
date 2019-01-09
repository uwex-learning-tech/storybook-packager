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
    @IBOutlet weak var deleteBtn: NSButton!
    @IBOutlet weak var noPageSelectedBox: NSBox!
    @IBOutlet weak var multiPagesSelectedBox: NSBox!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do view setup here
        pageCollectionScroller.scrollerStyle = .overlay
        
        multiPagesSelectedBox.isHidden = true
        
        // disable delete button on inital load
        disableDeleteBtn()
        
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
                    
                    if self.pageCollectionView.selectionIndexPaths.count == 1 {
                        self.updatePageDetailsView(indexPath: self.document!.currentPageIndex)
                    }
                    
                    self.dismiss(settingsDialogController)
                    
                }
                
            }
            
            self.presentAsSheet(settingsDialogController)
            
        }
        
    }
    
    private func setFields() {
        
        self.pages = self.document?.getXmlObjPages()
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
    
    // function to enable delete button
    private func enableDeleteBtn() {

        deleteBtn.isEnabled = true
        
        if let mutableAttributedTitle = deleteBtn.attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: NSColor.systemRed, range: NSRange(location: 0, length: mutableAttributedTitle.length))
            deleteBtn.attributedTitle = mutableAttributedTitle
        }
        
    }
    
    // function to disable delete button
    private func disableDeleteBtn() {
        
        deleteBtn.isEnabled = false
        
        if let mutableAttributedTitle = deleteBtn.attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: NSColor.systemGray, range: NSRange(location: 0, length: mutableAttributedTitle.length))
            deleteBtn.attributedTitle = mutableAttributedTitle
        }
        
    }
    
    // delete selected page item
    @IBAction func deletePageItem(_ sender: NSButton) {
        
//        let indexSet = pageCollectionView.selectionIndexPaths
//
//        if !indexSet.isEmpty {
//
//            for index in indexSet {
//
//                print("deleting \(index)...")
//
//                let currentPage = self.pages![index.item]
//
//                if currentPage.type == "section" {
//
//                    document?.getXmlObj().deleteSection(at: currentPage.num)
//
//                } else {
//
//                    document?.getXmlObj().deletePage(item: currentPage.index.item, at: currentPage.index.section)
//
//                }
//
//            }
//
//            clearPageDetails()
//            pages = document!.getXmlObj().getSectionAsPages()
//            pageCollectionView.reloadData()
//            document?.updateChangeCount(.changeDone)
//
//        }
        
    }
    
}

extension PresentationViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            let index = indexPath.item
            
            if (self.pages![index].type != "section") {
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageViewItem"), for: indexPath) as! PageViewItem
                
                item.typeLbl.stringValue = self.pages![index].type.uppercased().replacingOccurrences(of: "-", with: " & ")
                item.countLbl.stringValue = "\(self.pages![index].number + 1)"
                item.titleLbl.stringValue = self.pages![index].title
                
                return item
                
            } else {
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageSectionItem"), for: indexPath) as! PageSectionItem
                
                item.titleLbl.stringValue = self.pages![index].title
                
                if (self.pages![index].title.isEmpty) {
                    item.titleLbl.stringValue = "Section \(self.pages![index].number + 1)"
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
                    item.titleTxtfld.stringValue = "Section \(page.number + 1)"
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
                item.notesTxtvw.string = page.notes
                
                return item
                
            case "image-audio":
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ImageAudioViewItem"), for: indexPath) as! ImageAudioViewItem
                
                item.titleTxtfld.stringValue = page.title
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
            
            return CGSize(width: collectionView.bounds.width, height: collectionView.bounds.height)
            
        }
        
    }
    
    // select page cell
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        
        if collectionView.selectionIndexPaths.count == 1 {
            
            noPageSelectedBox.isHidden = true
            updatePageDetailsView(indexPath: indexPaths.first!)
            
        } else if collectionView.selectionIndexPaths.count > 1 {
            
            noPageSelectedBox.isHidden = true
            multiPagesSelectedBox.isHidden = false
            clearPageDetails()
            
        }
        
        // enable delete button if it does not contains the first item
        if !collectionView.selectionIndexPaths.contains(IndexPath(item: 0, section: 0))
        && !indexPaths.contains(IndexPath(item: 0, section: 0)){
            enableDeleteBtn()
        } else {
            disableDeleteBtn()
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
    
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        
        // disable delete button if none selected
        if collectionView.selectionIndexPaths.isEmpty {
            multiPagesSelectedBox.isHidden = true
            noPageSelectedBox.isHidden = false
            disableDeleteBtn()
            clearPageDetails()
        }
        
    }
    
    func clearPageDetails() {
        numOfSelected = 0
        pageDetailsView.reloadData()
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
    
    func updatePage() {
        
        // reset
        //pages = document!.getXmlObj().getSectionAsPages()
        
        // reload
        forUpdating = true
        pageCollectionView.deselectAll(nil)
        pageCollectionView.reloadItems(at: [document!.currentPageIndex])
        pageCollectionView.selectItems(at: [document!.currentPageIndex], scrollPosition: [])
        pageCollectionView.delegate?.collectionView!(pageCollectionView, didSelectItemsAt: [document!.currentPageIndex])
        
    }
    
    func refreshView() {
    
        //pages = document!.getXmlObj().getSectionAsPages()
        
        let indexPath = IndexPath(item: pages!.count-1, section: 0)
        
        pageCollectionView.deselectAll(nil)
        pageCollectionView.reloadData()
        pageCollectionView.selectItems(at: [indexPath], scrollPosition: NSCollectionView.ScrollPosition.centeredVertically)
        pageCollectionView.delegate?.collectionView!(pageCollectionView, didSelectItemsAt: [indexPath])
        
        updatePageDetailsView(indexPath: IndexPath(item: pages!.count-1, section: 0))
        
    }
    
    func updatePageDetailsView(indexPath: IndexPath) {
        document?.currentPageIndex = indexPath
        numOfSelected = 1
        pageDetailsView.reloadData()
    }
    
}
