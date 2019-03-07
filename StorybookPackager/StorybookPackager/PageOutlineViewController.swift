//
//  PageOutlineViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/6/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class PageOutlineViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    private var pages: Array<Page>?
    
    @IBOutlet weak var pageOutlineView: NSOutlineView!
    @IBOutlet weak var deleteBtn: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pageOutlineView.intercellSpacing = NSMakeSize(0,10)
        pageOutlineView.selectionHighlightStyle = .none
        disableDeleteBtn()
        NotificationCenter.default.addObserver(self, selector: #selector(self.projectLoaded), name: Notification.Name("projectLoaded"), object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        guard let document = NSDocumentController.shared.currentDocument as? Document else { return }
        pages = document.getXmlObjPages()
        
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
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        
        var view: PageOutlineCellView?
        
        view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageCell"), owner: self) as? PageOutlineCellView
        
        if let page = item as? Page {
            
            if page.type != "section" {
                view?.pageNumberLbl.stringValue = "\(page.number + 1)"
                view?.pageTypeLbl.stringValue = page.type.uppercased().replacingOccurrences(of: "-", with: " & ")
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
        
        guard let document = NSDocumentController.shared.currentDocument as? Document else { return }
        
        if indexes.count >= 1 {
            document.currentPageIndex = indexes
        } else {
            document.currentPageIndex = [-1]
        }
        
    }
    
    /** IB ACTIONs **/
    @IBAction func addSection(_ sender: NSButton) {
        
        guard let document = NSDocumentController.shared.currentDocument as? Document else { return }
        
        let section = Page()
        
        section.type = PageTypes.SECTION
        
        document.addSbSection(section: section)
        
        // refreash
        pages = document.getXmlObjPages()
        pageOutlineView.reloadData()
        pageOutlineView.scrollRowToVisible(pages!.count - 1)
        pageOutlineView.selectRowIndexes([pageOutlineView.row(forItem: pageOutlineView.item(atRow: pages!.count - 1))], byExtendingSelection: false)
        
    }
    
    @IBAction func addPage(_ sender: NSButton) {
        
        guard let document = NSDocumentController.shared.currentDocument as? Document else { return }
        
        let prefSettings = UserDefaults.standard
        let page = Page()
        
        page.title = "Untitled"
        page.type = prefSettings.string(forKey: Preferences.PAGE_TYPE)!
        
        document.addSbPage(page: page)
        
        // refreash
        pages = document.getXmlObjPages()
        pageOutlineView.reloadData()
        pageOutlineView.scrollRowToVisible(pages!.count - 1)
        pageOutlineView.selectRowIndexes([pageOutlineView.row(forItem: pageOutlineView.item(atRow: pages!.count - 1))], byExtendingSelection: false)
        
        // refreash
        //refreshPageCollection(refreshOnly: false, scroll: true, updateSelection: false, document: document)
        
    }
    
    @IBAction func deletePage(_ sender: NSButton) {
        
        guard let document = NSDocumentController.shared.currentDocument as? Document else { return }
        
        document.deletePage(indexes: pageOutlineView.selectedRowIndexes)
        
        // refreash
        pages = document.getXmlObjPages()
        pageOutlineView.reloadData()
        disableDeleteBtn()
        
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
        self.view.window?.makeFirstResponder(nil)
        NotificationCenter.default.post(name: Notification.Name("deteletBtnStateChanged"), object: nil, userInfo: ["enabled":true])
    }
    
    /** NOTIFICATION FUNCTIONS **/
    @objc func projectLoaded(_ sender: Notification) {
        
        // get all Storybook pages from current document
        guard let document = sender.object as? Document else { return }
        pages = document.getXmlObjPages()
        
        if pages != nil {
            pageOutlineView.reloadData()
        }
        
    }

    
}
