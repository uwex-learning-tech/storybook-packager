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
    
    @IBOutlet weak var pageOutlineView: NSOutlineView!
    @IBOutlet weak var deleteBtn: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        
        if currentDocument != nil {
            pages = currentDocument!.getXmlObjPages()
        }
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard pages?.count != nil else { return 0 }
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
        
        if indexes.count == 1 {
            NotificationCenter.default.post(name: Notification.Name("pageSelected"), object: currentDocument!)
        }
        
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
            pages![index].type = "MOVE"
            
        }
        
        var newIndex = index
        
        for page in pagesToMove {
            pages!.insert(page, at: newIndex)
            newIndex = newIndex + 1
        }
        
        pages!.removeAll(where: {$0.type == "MOVE"})
        currentDocument!.setXmlObjPages(pages: pages!)
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
        
        let section = Page()
        
        section.type = PageTypes.SECTION
        section.title = "Untitled"
        
        currentDocument!.addSbSection(section: section)
        
        // refreash
        pages = currentDocument!.getXmlObjPages()
        pageOutlineView.reloadData()
        pageOutlineView.scrollRowToVisible(pages!.count - 1)
        pageOutlineView.selectRowIndexes(NSIndexSet(index: pages!.count - 1) as IndexSet, byExtendingSelection: false)
        
    }
    
    @IBAction func addPage(_ sender: NSButton) {
        
        let prefSettings = UserDefaults.standard
        let page = Page()
        
        page.title = "Untitled"
        page.type = prefSettings.string(forKey: Preferences.PAGE_TYPE)!
        
        currentDocument!.addSbPage(page: page)
        
        // refreash
        pages = currentDocument!.getXmlObjPages()
        pageOutlineView.reloadData()
        pageOutlineView.scrollRowToVisible(pages!.count - 1)
        pageOutlineView.selectRowIndexes(NSIndexSet(index: pages!.count - 1) as IndexSet, byExtendingSelection: false)
        
    }
    
    @IBAction func deletePage(_ sender: NSButton) {
        
        currentDocument!.deletePage(indexes: pageOutlineView.selectedRowIndexes)
        currentDocument!.currentPageIndex = []
        
        // refreash
        pages = currentDocument!.getXmlObjPages()
        pageOutlineView.reloadData()
        disableDeleteBtn()
        
        NotificationCenter.default.post(name: Notification.Name("pageSelected"), object: currentDocument!)
        
    }
    
    /*** PRIVATE METHODS ***/
    
    private func disableDeleteBtn() {
        deleteBtn.isEnabled = false
        deleteBtn.state = .off
        deleteBtn.image = Bundle.main.image(forResource: "delete_alt_icn")
        NotificationCenter.default.post(name: Notification.Name("deteletBtnStateChanged"), object: nil, userInfo: ["enabled":false])
    }
    
    private func enableDeleteBtn() {
        deleteBtn.isEnabled = true
        deleteBtn.state = .on
        deleteBtn.image = Bundle.main.image(forResource: "delete_icn")
        //self.view.window?.makeFirstResponder(nil)
        NotificationCenter.default.post(name: Notification.Name("deteletBtnStateChanged"), object: nil, userInfo: ["enabled":true])
    }
    
    /** NOTIFICATION FUNCTIONS **/
    
    @objc func reloadPageOutline(_ sender: Notification) {
        
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
            }
            
        }
        
    }

    
}
