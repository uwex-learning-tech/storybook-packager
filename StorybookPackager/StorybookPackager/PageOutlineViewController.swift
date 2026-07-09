//
//  PageOutlineViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/6/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class PageOutlineViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, NSMenuItemValidation {
    
    private var currentDocument: Document?
    private var pages: Array<Page>?
    private var dragAndDropIndice: IndexSet = []
    
    @IBOutlet weak var pageScrollView: NSScrollView!
    @IBOutlet weak var pageOutlineView: NSOutlineView!
    @IBOutlet weak var addPageBtn: NSButton!
    @IBOutlet weak var addSectionBtn: NSButton!
    @IBOutlet weak var deleteBtn: NSButton!
    @IBOutlet weak var confirmTitleBtn: NSButton!
    @IBOutlet weak var emptyMsg: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pageScrollView.automaticallyAdjustsContentInsets = false
        pageScrollView.contentInsets = NSEdgeInsets(top: 5.0, left: 0, bottom: 5.0, right: 0)
        
        pageOutlineView.intercellSpacing = NSMakeSize(0, 10)
        pageOutlineView.ignoresMultiClick = true
        
        pageOutlineView.registerForDraggedTypes([NSPasteboard.PasteboardType.string, NSPasteboard.PasteboardType.storybookPages])
        pageOutlineView.setDraggingSourceOperationMask(.move, forLocal: true)
        pageOutlineView.setDraggingSourceOperationMask(.copy, forLocal: false)
        
        emptyMsg.isHidden = true
        disableDeleteBtn()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.addNewPage), name: Notification.Name("addNewPage"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.addNewSection), name: Notification.Name("addNewSection"), object: nil)
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
        
        if pages!.count >= 1 {
            checkPageTitles()
            emptyMsg.isHidden = true
            confirmTitleBtn.isEnabled = true
        } else {
            emptyMsg.isHidden = false
            confirmTitleBtn.isEnabled = false
        }
        
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
        
        if indexes.count >= 1 {
            enableDeleteBtn()
            currentDocument!.currentPageIndex = indexes
        } else {
            disableDeleteBtn()
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

        // Also carry a self-contained copy payload (pages + asset bytes) so the drag can land in
        // another open presentation, surviving even if this document is later closed.
        if let data = currentDocument?.makePagesClipboardData(forFlatRows: dragAndDropIndice) {
            session.draggingPasteboard.setData(data, forType: .storybookPages)
        }

    }
    
    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        
        dragAndDropIndice = []
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {

        // A drag carrying a copy payload from another presentation (or this one) is copy-only;
        // disallow index 0/-1 to keep the first section in place.
        if isForeignDrop(info) {
            return (index == 0 || index == -1) ? NSDragOperation() : .copy
        }

        if index != 0 {
            return .move
        }

        return NSDragOperation()

    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {

        guard index != -1  else { return false }

        // Foreign drop: copy the carried pages/assets in. Never touches `pages`/`dragAndDropIndice`
        // and never mutates the source document.
        if isForeignDrop(info) {

            guard let data = info.draggingPasteboard.data(forType: .storybookPages) else { return false }
            guard let count = currentDocument?.insertClipboardData(data, atFlatIndex: index), count > 0 else { return false }

            pages = currentDocument?.getXmlObjPages()

            let lastRow = min(index + count - 1, (pages?.count ?? 1) - 1)
            currentDocument!.currentPageIndex = lastRow >= 0 ? [lastRow] : []
            currentDocument!.updateChangeCount(.changeDone)

            NotificationCenter.default.post(name: Notification.Name("reloadPageOutline"), object: currentDocument!)

            return true

        }

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

        if let first = dragAndDropIndice.first, first < index {
            outlineView.selectRowIndexes([pageOutlineView.row(forItem: pageOutlineView.item(atRow: index - 1))], byExtendingSelection: true)

        } else {
            outlineView.selectRowIndexes([pageOutlineView.row(forItem: pageOutlineView.item(atRow: index))], byExtendingSelection: true)
        }

        currentDocument!.updateChangeCount(.changeDone)

        return true

    }

    // True when the drop carries a copy payload that did not originate from this outline view —
    // i.e. it must be copied in rather than reordered. The empty dragAndDropIndice is a secondary
    // guard against the old intra-doc reorder path running on a foreign drag.
    private func isForeignDrop(_ info: NSDraggingInfo) -> Bool {
        guard info.draggingPasteboard.data(forType: .storybookPages) != nil else { return false }
        return (info.draggingSource as AnyObject?) !== pageOutlineView || dragAndDropIndice.isEmpty
    }

    /** COPY & PASTE & DUPLICATE (Edit menu / ⌘C ⌘V ⌘D) */

    @objc func copy(_ sender: Any?) {

        guard let data = currentDocument?.makePagesClipboardData(forFlatRows: pageOutlineView.selectedRowIndexes) else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.storybookPages], owner: nil)
        pasteboard.setData(data, forType: .storybookPages)

    }

    @objc func paste(_ sender: Any?) {

        guard let data = NSPasteboard.general.data(forType: .storybookPages) else { return }

        // Insert after the last selected row, or at the end when nothing is selected.
        let insertIndex = pageOutlineView.selectedRowIndexes.last.map { $0 + 1 } ?? pageOutlineView.numberOfRows
        insertClipboard(data, atFlatIndex: insertIndex)

    }

    // Duplicate the selected section(s)/page(s) in place: build the same independent-copy payload the
    // clipboard uses, then insert it right after the selection — no pasteboard involved.
    @objc func duplicate(_ sender: Any?) {

        let selected = pageOutlineView.selectedRowIndexes
        guard !selected.isEmpty else { return }
        guard let data = currentDocument?.makePagesClipboardData(forFlatRows: selected) else { return }

        insertClipboard(data, atFlatIndex: selected.last! + 1)

    }

    // Insert a clipboard/duplicate payload at the given flat row, then select the inserted pages.
    private func insertClipboard(_ data: Data, atFlatIndex insertIndex: Int) {

        guard let count = currentDocument?.insertClipboardData(data, atFlatIndex: insertIndex), count > 0 else { return }

        pages = currentDocument?.getXmlObjPages()

        let lastRow = min(insertIndex + count - 1, (pages?.count ?? 1) - 1)
        currentDocument!.currentPageIndex = lastRow >= 0 ? [lastRow] : []
        currentDocument!.updateChangeCount(.changeDone)

        NotificationCenter.default.post(name: Notification.Name("reloadPageOutline"), object: currentDocument!)

    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {

        switch menuItem.action {
        case #selector(copy(_:)), #selector(duplicate(_:)):
            return !pageOutlineView.selectedRowIndexes.isEmpty
        case #selector(paste(_:)):
            return NSPasteboard.general.data(forType: .storybookPages) != nil
        default:
            return true
        }

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
    
    @objc func addNewSection(_ sender: Notification) {
        
        // get all Storybook pages from current document
        guard let document = sender.object as? Document else { return }
        guard currentDocument != nil else { return }
        
        if document == currentDocument! {
            addSection(addSectionBtn)
        }
        
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
    
    @objc func addNewPage(_ sender: Notification) {
        
        // get all Storybook pages from current document
        guard let document = sender.object as? Document else { return }
        guard currentDocument != nil else { return }
        
        if document == currentDocument! {
            addPage(addPageBtn)
        }
        
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
        
        if pageOutlineView.selectedRowIndexes.contains(rowIndex) {
            NotificationCenter.default.post(name: Notification.Name("pageSelected"), object: currentDocument!)
        }
        
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
        deleteBtn.contentTintColor = .controlColor
        NotificationCenter.default.post(name: Notification.Name("deleteBtnStateChanged"), object: nil, userInfo: ["enabled":false])
    }
    
    private func enableDeleteBtn() {
        deleteBtn.isEnabled = true
        deleteBtn.state = .on
        deleteBtn.contentTintColor = .systemRed
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
        guard currentDocument != nil else { return }
        
        if document == currentDocument! {

            // A sender that names its page refreshes that row: the auto-OCR title lands well after
            // its import finished, so the page it renamed is often not the selected one — and after
            // a delete-all there may be no selection at all.
            if let page = sender.userInfo?["page"] as? Page {

                let row = pageOutlineView.row(forItem: page)
                guard row >= 0 else { return }
                pageOutlineView.reloadItem(pageOutlineView.item(atRow: row))

                return

            }

            guard let row = currentDocument!.currentPageIndex.first else { return }
            pageOutlineView.reloadItem(pageOutlineView.item(atRow: row))

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
