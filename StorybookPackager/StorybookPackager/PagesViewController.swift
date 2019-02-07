//
//  PagesViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/7/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class PagesViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var pageScrollView: NSScrollView!
    @IBOutlet weak var pageCollectionView: NSCollectionView!
    @IBOutlet weak var deleteBtn: NSButton!
    @IBOutlet weak var touchBarDeleteBtn: NSButton!
    
    private var document: Document?
    private var pages: Array<Page>?
    private var needUpdating: Bool = true
    private var dragAndDropIndice: Set<IndexPath> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // for scroll bar style to be an overlay
        pageScrollView.scrollerStyle = .overlay
        
        // enable drag and drop for page collection view
        pageCollectionView.registerForDraggedTypes([NSPasteboard.PasteboardType(kUTTypeItem as String)])
        pageCollectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        
        // disable delete button on inital load
        disableDeleteBtn()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadPageCollection), name: Notification.Name("reloadPageCollection"), object: nil)
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // get current document instance
        document = NSDocumentController.shared.currentDocument as? Document
        
        // get all Storybook pages from current document
        pages = document?.getXmlObjPages()
        
        if pages != nil {
            pageCollectionView.reloadData()
        }
        
    }
    
    /*** IB ACTIONS ***/
    
    @IBAction func addPage(_ sender: NSButton) {
        
        let page = Page()
        
        page.title = "Untitled"
        page.type = PageTypes.IMAGE_AUDIO
        
        document!.addSbPage(page: page)
        document!.currentPageIndex = [IndexPath(item: pages!.count, section: 0)]
        
        // refreash
        refreshPageCollection(scroll: true, updateSelected: false, reloadAll: true)
        
    }
    
    @IBAction func addSection(_ sender: NSButton) {
        

        let section = Page()
        
        section.type = PageTypes.SECTION
        
        document!.addSbSection(section: section)
        document!.currentPageIndex = [IndexPath(item: pages!.count, section: 0)]
        
        // refreash
        refreshPageCollection(scroll: true, updateSelected: false, reloadAll: true)
        
    }
    
    @IBAction func deletePageItem(_ sender: NSButton) {
        
        document!.deletePage(indexPaths: pageCollectionView.selectionIndexPaths)
        
        // refreash
        refreshPageCollection(scroll: true, updateSelected: true, reloadAll: true)
        
        
    }
    
    /*** PRIVATE METHODS ***/
    
    private func disableDeleteBtn() {
        touchBarDeleteBtn.isEnabled = false
        deleteBtn.isEnabled = false
        deleteBtn.state = .off
        deleteBtn.image = Bundle.main.image(forResource: "delete_alt_icn")
    }
    
    private func enableDeleteBtn() {
        touchBarDeleteBtn.isEnabled = true
        deleteBtn.isEnabled = true
        deleteBtn.state = .on
        deleteBtn.image = Bundle.main.image(forResource: "delete_icn")
    }
    
    private func refreshPageCollection(scroll: Bool, updateSelected: Bool, reloadAll: Bool) {
        
        pages = self.document?.getXmlObjPages()
        
        needUpdating = updateSelected
        pageCollectionView.deselectAll(nil)
        
        if reloadAll {
            pageCollectionView.reloadData()
        } else {
            pageCollectionView.reloadItems(at: document!.currentPageIndex)
        }
        
        pageCollectionView.selectItems(at: document!.currentPageIndex, scrollPosition: scroll ? NSCollectionView.ScrollPosition.centeredVertically : [])
        pageCollectionView.delegate?.collectionView!(pageCollectionView, didSelectItemsAt: document!.currentPageIndex)
        
    }
    
    /*** OBJECTIVE-C METHODS ***/
    
    @objc func reload(_ sender: NSNotification) {
        
        refreshPageCollection(scroll: true, updateSelected: false, reloadAll: false)
        
    }
    
    /*** PROTOCOLS TO SETUP PAGE COLLECTION DATA SOURCE ***/
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let count = pages?.count else { return 0 }
        return count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        let index = indexPath.item
        var item: NSCollectionViewItem = NSCollectionViewItem()
        
        guard let page = pages?[index] else { return item }
        
        switch page.type {
        case PageTypes.SECTION:
            
            item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.PAGE_SECTION_ITEM), for: indexPath) as! PageSectionItem
            
            (item as! PageSectionItem).titleLbl.stringValue = page.title.isEmpty ? "Section \(page.number + 1)" : page.title
            
        default:
            
            item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.PAGE_VIEW_ITEM), for: indexPath) as! PageViewItem
            
            (item as! PageViewItem).typeLbl.stringValue = page.type.uppercased().replacingOccurrences(of: "-", with: " & ")
            (item as! PageViewItem).countLbl.stringValue = "\(page.number + 1)"
            (item as! PageViewItem).titleLbl.stringValue = page.title
            
        }
        
        return item
        
    }
    
    /*** PROTOCOLS TO SETUP PAGE COLLECTION LAYOUT DELEGATE ***/
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        
        let itemWidth = pageCollectionView.bounds.width - 20
        var itemHeight = PageViewItem().view.bounds.height
        
        if (pages![indexPath.item].type == PageTypes.SECTION) {
            itemHeight = PageSectionItem().view.bounds.height
        }
        
        return CGSize(width: itemWidth, height: itemHeight)
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        
        document?.currentPageIndex = collectionView.selectionIndexPaths
        
        NotificationCenter.default.post(name: Notification.Name("reloadPageEdit"), object: nil)
        
        if !indexPaths.contains(IndexPath(item: 0, section: 0)) {
            enableDeleteBtn()
        } else {
            disableDeleteBtn()
        }
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        
        if needUpdating {
            document?.currentPageIndex = collectionView.selectionIndexPaths
        }
        
        needUpdating = true
        
        NotificationCenter.default.post(name: Notification.Name("reloadPageEdit"), object: nil)
        
        // disable delete button if none selected
        if collectionView.selectionIndexPaths.isEmpty {
            disableDeleteBtn()
        }
        
    }
    
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
                document!.reorder(from: fromIndexPath.item, to: indexPath.item)
                refreshPageCollection(scroll: false, updateSelected: false, reloadAll: true)
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
    
}
