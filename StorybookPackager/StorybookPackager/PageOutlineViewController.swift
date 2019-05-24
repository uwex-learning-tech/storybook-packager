//
//  PageOutlineViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/6/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import sbplus_xml_parser

class PageOutlineViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    private var currentDocument: Document?
    private var pages: Array<Page>?
    private var dragAndDropIndice: IndexSet = []
    
    @IBOutlet weak var pageScrollView: NSScrollView!
    @IBOutlet weak var pageOutlineView: NSOutlineView!
    @IBOutlet weak var deleteBtn: NSButton!
    @IBOutlet weak var confirmTitleBtn: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pageScrollView.automaticallyAdjustsContentInsets = false
        pageScrollView.contentInsets = NSEdgeInsets(top: 5.0, left: 0, bottom: 5.0, right: 0)
        
        pageOutlineView.intercellSpacing = NSMakeSize(0, 10)
        pageOutlineView.ignoresMultiClick = true
        
        pageOutlineView.registerForDraggedTypes([NSPasteboard.PasteboardType.string])
        pageOutlineView.setDraggingSourceOperationMask(.move, forLocal: true)
        
        disableDeleteBtn()
        NotificationCenter.default.addObserver(self, selector: #selector(self.projectLoaded), name: Notification.Name("projectLoaded"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.refreashCell), name: Notification.Name("refreshCell"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadPageOutline), name: Notification.Name("reloadPageOutline"), object: nil)
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        currentDocument = NSDocumentController.shared.currentDocument as? Document
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard pages?.count != nil else { return 0 }
        checkPageTitles()
        return pages!.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard pages?.count != nil else { return 0 }
        return pages![index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return PageOutlineTableRowView()
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        
        var view: PageOutlineCellView?
        
        view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageCell"), owner: self) as? PageOutlineCellView
        
        if let page = item as? Page {
            
            if page.type != PageTypes.SECTION {
                
                view?.pageNumberLbl.stringValue = "\(page.number + 1)"
                
                if page.type == PageTypes.QUIZ {
                    view?.pageTypeLbl.stringValue = page.type.uppercased().replacingOccurrences(of: "-", with: " & ") + " - " + Util.shared.getQuizType(type: page.quiz.type).uppercased()
                } else {
                    view?.pageTypeLbl.stringValue = page.type.uppercased().replacingOccurrences(of: "-", with: " & ")
                }
                
                view?.pageTypeLbl.isHidden = false
                
            } else {
                view?.pageNumberLbl.stringValue = page.type.uppercased().replacingOccurrences(of: "-", with: " & ") + " \(page.number + 1)"
                view?.pageTypeLbl.isHidden = true
            }
            
            if Util.shared.needToConfirmTitle(string: page.title) {
                
                view?.confirmTitleBtn.isEnabled = true
                view?.confirmTitleBtn.isHidden = false
                
            } else {
                
                view?.confirmTitleBtn.isEnabled = false
                view?.confirmTitleBtn.isHidden = true
                
            }
            
            view?.pageTitleLbl.stringValue = page.title
            
        }
        
        return view
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
        
        outlineView.deselectAll(self)
        
        return proposedSelectionIndexes
        
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        
        let indexes = pageOutlineView.selectedRowIndexes
        
        if indexes.count >= 1 && !indexes.contains(0) {
            enableDeleteBtn()
        } else {
            disableDeleteBtn()
        }
        
        if indexes.count >= 1 {
            currentDocument!.currentPageIndex = indexes
        } else {
            currentDocument!.currentPageIndex = []
        }
    
        NotificationCenter.default.post(name: Notification.Name("pageSelected"), object: currentDocument!)

    }
    
    /** DRAG & DROP PROTOCOLS */
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        
        let pageItem = NSPasteboardItem()
        let page = item as? Page
        
        pageItem.setData(Data(page!.title.utf8), forType: NSPasteboard.PasteboardType.string)
        
        return pageItem
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItems draggedItems: [Any]) {
        
        for item in draggedItems {
            dragAndDropIndice.insert(outlineView.row(forItem: item))
        }
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        
        dragAndDropIndice = []
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        
        if index != 0 {
            return .move
        }
        
        return NSDragOperation()
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        
        guard index != -1  else { return false }
        
        if currentDocument!.numSections() >= 1 {
            guard dragAndDropIndice.first != 0 else { return false }
        }
        
        var pagesToMove: Array<Page> = []
        
        for index in dragAndDropIndice {
            
            let page: Page = pages![index].copy(with: nil) as! Page
            pagesToMove.append(page)
            pages![index].type = PageTypes._MOVE
            
        }
        
        var newIndex = index
        
        for page in pagesToMove {
            pages!.insert(page, at: newIndex)
            newIndex = newIndex + 1
        }
        
        pages!.removeAll(where: {$0.type == PageTypes._MOVE})
        currentDocument!.refreshPageCollectionWithNew(pages: pages!)
        pages = currentDocument?.getXmlObjPages()
        
        outlineView.reloadData()
        
        if dragAndDropIndice.first! < index {
            outlineView.selectRowIndexes([pageOutlineView.row(forItem: pageOutlineView.item(atRow: index - 1))], byExtendingSelection: true)
            
        } else {
            outlineView.selectRowIndexes([pageOutlineView.row(forItem: pageOutlineView.item(atRow: index))], byExtendingSelection: true)
        }
        
        currentDocument!.updateChangeCount(.changeDone)
        
        return true
        
    }
    
    /** IB ACTIONs **/
    @IBAction func addSection(_ sender: NSButton) {
        
        var newIndex = pageOutlineView.selectedRow
        let section = Page()
        
        section.type = PageTypes.SECTION
        section.title = "[Untitled]"
        
        if let selected = pageOutlineView.selectedRowIndexes.last {
            
            currentDocument!.addSbSection(section: section, index: selected + 1)
            newIndex = selected + 1
            
        } else {
            
            currentDocument!.addSbSection(section: section)
            
            if currentDocument!.numSections() == 2 {
                newIndex = pages!.count + 1
            } else {
                newIndex = pages!.count
            }
            
        }
        
        // refreash
        pages = currentDocument!.getXmlObjPages()
        pageOutlineView.reloadData()
        pageOutlineView.scrollRowToVisible(newIndex)
        pageOutlineView.selectRowIndexes(NSIndexSet(index: newIndex) as IndexSet, byExtendingSelection: false)
        
    }
    
    @IBAction func addPage(_ sender: NSButton) {
        
        let prefSettings = UserDefaults.standard
        let page = Page()
        var newIndex = pageOutlineView.selectedRow
        
        page.title = "[Untitled]"
        page.type = prefSettings.string(forKey: Preferences.PAGE_TYPE)!
        
        if let selected = pageOutlineView.selectedRowIndexes.last {
            currentDocument!.addSbPage(page: page, index: selected + 1)
            newIndex = selected + 1
        } else {
            currentDocument!.addSbPage(page: page)
            newIndex = pages!.count
        }
        
        // refreash
        pages = currentDocument!.getXmlObjPages()
        pageOutlineView.reloadData()
        pageOutlineView.scrollRowToVisible(newIndex)
        pageOutlineView.selectRowIndexes(NSIndexSet(index: newIndex) as IndexSet, byExtendingSelection: false)
        
    }
    
    @IBAction func deletePage(_ sender: NSButton) {
        
        let selectedIndexes = pageOutlineView.selectedRowIndexes
        
        currentDocument!.deletePage(indexes: selectedIndexes)
        
        // refreash
        pages = currentDocument!.getXmlObjPages()
        pageOutlineView.reloadData()
        pageOutlineView.scrollRowToVisible(selectedIndexes.first! - 1)
        pageOutlineView.selectRowIndexes([selectedIndexes.first! - 1], byExtendingSelection: false)
        
    }
    
    @IBAction func confirmTitle(_ sender: NSButton) {
        
        let rowIndex = pageOutlineView.row(for: sender.superview!)
        
        currentDocument!.getXmlObjPages()[rowIndex].title = currentDocument!.getXmlObjPages()[rowIndex].title.trimmingCharacters(in: [" ", "[", "]"])
        
        pageOutlineView.reloadItem(pageOutlineView.item(atRow: rowIndex))
        pageOutlineView.selectRowIndexes([rowIndex], byExtendingSelection: false)
        
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    @IBAction func confirmAllTitles(_ sender: NSButton) {
        
        guard currentDocument != nil else { return }
        let selectIndex: IndexSet = currentDocument!.currentPageIndex
        
        for (index, _) in pages!.enumerated() {
            currentDocument!.getXmlObjPages()[index].title = currentDocument!.getXmlObjPages()[index].title.trimmingCharacters(in: [" ", "[", "]"])
        }
        
        pages = currentDocument!.getXmlObjPages()
        pageOutlineView.reloadData()
        
        if !selectIndex.isEmpty {
            pageOutlineView.selectRowIndexes([selectIndex.first!], byExtendingSelection: false)
        }
        
        sender.image = NSImage(named: "text_check")?.imageTint(withColor: NSColor.systemGray)
        NotificationCenter.default.post(name: Notification.Name("confirmTitleBtnStateChanged"), object: nil, userInfo: ["enabled":false])
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    /*** PRIVATE METHODS ***/
    
    private func disableDeleteBtn() {
        deleteBtn.isEnabled = false
        deleteBtn.state = .off
        deleteBtn.image = Bundle.main.image(forResource: "delete_alt_icn")
        NotificationCenter.default.post(name: Notification.Name("deleteBtnStateChanged"), object: nil, userInfo: ["enabled":false])
    }
    
    private func enableDeleteBtn() {
        deleteBtn.isEnabled = true
        deleteBtn.state = .on
        deleteBtn.image = Bundle.main.image(forResource: "delete_icn")
        //self.view.window?.makeFirstResponder(nil)
        NotificationCenter.default.post(name: Notification.Name("deleteBtnStateChanged"), object: nil, userInfo: ["enabled":true])
    }
    
    private func checkPageTitles() {
        
        for page in pages! {
            
            if Util.shared.needToConfirmTitle(string: page.title) {
                
                confirmTitleBtn.isEnabled = true
                confirmTitleBtn.image = NSImage(named: "text_check")?.imageTint(withColor: NSColor.systemYellow)
                NotificationCenter.default.post(name: Notification.Name("confirmTitleBtnStateChanged"), object: nil, userInfo: ["enabled":true])
                
                break
                
            }
            
            confirmTitleBtn.isEnabled = false
            
        }
        
    }
    
    /** NOTIFICATION FUNCTIONS **/
    
    @objc func reloadPageOutline(_ sender: Notification) {
        
        guard currentDocument != nil else { return }
        guard let document = sender.object as? Document else { return }
        
        if document == currentDocument! {
            
            var index = currentDocument!.currentPageIndex.first
            
            if sender.userInfo != nil && sender.userInfo!["selectLast"] as! Bool {
                index = pageOutlineView.numberOfRows
            }
            
            pages = currentDocument!.getXmlObjPages()
            pageOutlineView.reloadData()
            
            if index != nil && index != -1 {
                pageOutlineView.selectRowIndexes(NSIndexSet(index: index!) as IndexSet, byExtendingSelection: false)
                pageOutlineView.scrollRowToVisible(index!)
            }
            
            NotificationCenter.default.post(name: Notification.Name("pageSelected"), object: document)
            
        }
        
    }
    
    @objc func refreashCell(_ sender: Notification) {
        
        guard let document = sender.object as? Document else { return }
        
        if document == currentDocument! {
            
            pageOutlineView.reloadItem(pageOutlineView.item(atRow: currentDocument!.currentPageIndex.first!))
            
        }
        
    }
    
    @objc func projectLoaded(_ sender: Notification) {
        
        // get all Storybook pages from current document
        guard let document = sender.object as? Document else { return }
        guard currentDocument != nil else { return }
        
        if document == currentDocument! {
            
            pages = currentDocument!.getXmlObjPages()
            
            if pages != nil {
                pageOutlineView.reloadData()
                pageOutlineView.selectRowIndexes([0], byExtendingSelection: false)
                document.currentPageIndex = [0]
            }
            
        }
        
    }

    
}
