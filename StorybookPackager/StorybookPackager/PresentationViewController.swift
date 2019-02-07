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
    private var dragAndDropIndice: Set<IndexPath> = []
    
    @IBOutlet weak var pageDetailsScroller: NSScrollView!
    @IBOutlet weak var pageDetailsView: NSCollectionView!
    @IBOutlet weak var pageCollectionScroller: NSScrollView!
    @IBOutlet weak var pageCollectionView: NSCollectionView!
    @IBOutlet weak var deleteBtn: NSButton!
    @IBOutlet weak var noPageSelectedBox: NSBox!
    @IBOutlet weak var multiPagesSelectedBox: NSBox!
    @IBOutlet weak var touchBarDeleteBtn: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do view setup here
        pageCollectionScroller.scrollerStyle = .overlay
        multiPagesSelectedBox.isHidden = true
        
        // enable drag and drop for page collection view
        pageCollectionView.registerForDraggedTypes([NSPasteboard.PasteboardType(kUTTypeItem as String)])
        pageCollectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        
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
                        //self.updatePageDetailsView(indexPath: self.document!.currentPageIndex.first!)
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
    
}

extension PresentationViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        if (collectionView.identifier!.rawValue == ObjIdentifiers.PAGE_COLLECTION) {
            
            let index = indexPath.item
            
            if (self.pages![index].type != PageTypes.SECTION) {
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.PAGE_VIEW_ITEM), for: indexPath) as! PageViewItem
                
                item.typeLbl.stringValue = self.pages![index].type.uppercased().replacingOccurrences(of: "-", with: " & ")
                item.countLbl.stringValue = "\(self.pages![index].number + 1)"
                item.titleLbl.stringValue = self.pages![index].title
                
                return item
                
            } else {
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.PAGE_SECTION_ITEM), for: indexPath) as! PageSectionItem
                
                item.titleLbl.stringValue = self.pages![index].title
                
                if (self.pages![index].title.isEmpty) {
                    item.titleLbl.stringValue = "Section \(self.pages![index].number + 1)"
                } else {
                    item.titleLbl.stringValue = self.pages![index].title
                }
                
                return item
                
            }
            
        } else {
            
            let page = self.pages![document!.currentPageIndex.first!.item]
            
            switch page.type {
                
            case PageTypes.SECTION:
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.SECTION_VIEW_ITEM), for: indexPath) as! SectionViewItem
                
                if (page.title.isEmpty) {
                    item.titleTxtfld.stringValue = "Section \(page.number + 1)"
                } else {
                    item.titleTxtfld.stringValue = page.title
                }
                
                return item
                
            case PageTypes.KALTURA:
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.KALTURA_VIEW_ITEM), for: indexPath) as! KalturaViewItem
                
                item.titleTxtfld.stringValue = page.title
                item.notesTxtvw.string = page.notes
                
                return item
                
            case PageTypes.IMAGE:
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.IMAGE_VIEW_ITEM), for: indexPath) as! ImageViewItem
                
                item.titleTxtfld.stringValue = page.title
                item.notesTxtvw.string = page.notes
                
                return item
                
            case PageTypes.IMAGE_AUDIO:
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.IMAGE_AUDIO_VIEW_ITEM), for: indexPath) as! ImageAudioViewItem
                
                item.titleTxtfld.stringValue = page.title
                item.notesTxtvw.string = page.notes
                
                return item
                
            case PageTypes.YOUTUBE:
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.YOUTUBE_VIEW_ITEM), for: indexPath) as! YoutubeViewItem
                
                item.titleTxtfld.stringValue = page.title
                item.notesTxtvw.string = page.notes
                
                return item
                
            case PageTypes.VIMEO:
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.VIMEO_VIEW_ITEM), for: indexPath) as! VimeoViewItem
                
                item.titleTxtfld.stringValue = page.title
                item.notesTxtvw.string = page.notes
                
                return item
                
            case PageTypes.VIDEO:
                
                let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.VIDEO_VIEW_ITEM), for: indexPath) as! VideoViewItem
                
                item.titleTxtfld.stringValue = page.title
                item.notesTxtvw.string = page.notes
                
                return item
                
            default:

                return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.EMPTY), for: indexPath) as! EmptyViewItem

            }
            
        }
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {

        if (collectionView.identifier!.rawValue == ObjIdentifiers.PAGE_COLLECTION) {
            
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
        
        if (collectionView.identifier!.rawValue == ObjIdentifiers.PAGE_COLLECTION) {
            
            let itemWidth = pageCollectionView.bounds.width - 20
            var itemHeight = PageViewItem().view.bounds.height
            
            if (self.pages![indexPath.item].type == PageTypes.SECTION) {
                
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
           // updatePageDetailsView(indexPath: indexPaths.first!)
            
        } else if collectionView.selectionIndexPaths.count > 1 {
            
            noPageSelectedBox.isHidden = true
            multiPagesSelectedBox.isHidden = false
            //clearPageDetails()
            
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
            
            document?.currentPageIndex = [IndexPath(item: 0, section: 0)]
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
            //clearPageDetails()
        }
        
    }
    
    // drag and drop delegates
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        
        let pageItem = NSPasteboardItem()
        pageItem.setData(Data(pages![indexPath.item].title.utf8), forType: NSPasteboard.PasteboardType(kUTTypeItem as String))
        
        return pageItem
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexPaths: Set<IndexPath>) {
        dragAndDropIndice = indexPaths
    }
    
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, dragOperation operation: NSDragOperation) {
        dragAndDropIndice = []
    }
    
    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        
        if proposedDropOperation.pointee == NSCollectionView.DropOperation.on {
            proposedDropOperation.pointee = NSCollectionView.DropOperation.before
        }
        
        return NSDragOperation.move
    }
    
    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        
        if dragAndDropIndice.count == 1 {
            
            guard indexPath.item <= pageCollectionView.numberOfItems(inSection: 0) - 1 else { return false }
            
            if document!.numSections() >= 1 {
                guard dragAndDropIndice.first != IndexPath(item: 0, section: 0) else { return false }
            }
            
            for fromIndexPath in dragAndDropIndice {
                collectionView.moveItem(at: fromIndexPath, to: indexPath)
                self.document!.reorder(from: fromIndexPath.item, to: indexPath.item)
                //self.refreshPageCollection()
            }
            
        } else {

            let alert = NSAlert()
            alert.messageText = "Operation Not Supported"
            alert.informativeText = "Cannot reorder multiple items at a same time."
            alert.runModal()
            return false

        }
        
        return true
        
    }
    
    // IB button actions
    @IBAction func addPage(_ sender: NSButton) {
        
        // add
        let page = Page()
        
        page.title = "Untitled"
        page.type = "image-audio"
        
        document?.addSbPage(page: page)
        
        // refreash
        //refreshView()
        
    }
    
    @IBAction func addSection(_ sender: NSButton) {
        
        // add
        let section = Page()
        
        section.type = PageTypes.SECTION
        
        document?.addSbSection(section: section)
        
        // refreash
        //refreshView()
        
    }
    
    // function to enable delete button
    private func enableDeleteBtn() {
        
        touchBarDeleteBtn.isEnabled = true
        deleteBtn.isEnabled = true
        deleteBtn.state = .on
        deleteBtn.image = Bundle.main.image(forResource: "delete_icn")
        
    }
    
    // function to disable delete button
    private func disableDeleteBtn() {
        
        touchBarDeleteBtn.isEnabled = false
        deleteBtn.isEnabled = false
        deleteBtn.state = .off
        deleteBtn.image = Bundle.main.image(forResource: "delete_alt_icn")
        
    }
    
    // delete selected page item
    @IBAction func deletePageItem(_ sender: NSButton) {
            
        document?.deletePage(indexPaths: pageCollectionView.selectionIndexPaths)
        
        // refreash
        //refreshView()
        
    }
    
    func updatePage() {

        pages = self.document?.getXmlObjPages()

        // reload
        forUpdating = true
        pageCollectionView.deselectAll(nil)
        pageCollectionView.reloadItems(at: document!.currentPageIndex)
        pageCollectionView.selectItems(at: document!.currentPageIndex, scrollPosition: NSCollectionView.ScrollPosition.centeredVertically)
        pageCollectionView.delegate?.collectionView!(pageCollectionView, didSelectItemsAt: document!.currentPageIndex)

    }

//    func refreshPageCollection() {
//
//        pages = self.document?.getXmlObjPages()
//
//        // reload
//        forUpdating = true
//        pageCollectionView.deselectAll(nil)
//        pageCollectionView.reloadData()
//        pageCollectionView.selectItems(at: document!.currentPageIndex, scrollPosition: [])
//        pageCollectionView.delegate?.collectionView!(pageCollectionView, didSelectItemsAt: document!.currentPageIndex)
//
//    }
    
    func refreshCurrentPage() {
        
        pages = self.document?.getXmlObjPages()
        pageCollectionView.reloadItems(at: document!.currentPageIndex)
        pageCollectionView.selectItems(at: document!.currentPageIndex, scrollPosition: NSCollectionView.ScrollPosition.centeredVertically)
        
    }
    
//    func refreshView() {
//
//        pages = self.document?.getXmlObjPages()
//
//        let indexPath = IndexPath(item: pages!.count-1, section: 0)
//
//        pageCollectionView.deselectAll(nil)
//        pageCollectionView.reloadData()
//        pageCollectionView.selectItems(at: [indexPath], scrollPosition: NSCollectionView.ScrollPosition.centeredVertically)
//        pageCollectionView.delegate?.collectionView!(pageCollectionView, didSelectItemsAt: [indexPath])
//
//    }
    
//    func clearPageDetails() {
//        numOfSelected = 0
//        pageDetailsView.reloadData()
//    }
    
//    func updatePageDetailsView(indexPath: IndexPath) {
//        document?.currentPageIndex = [indexPath]
//        numOfSelected = 1
//        pageDetailsView.reloadData()
//    }
    
}
