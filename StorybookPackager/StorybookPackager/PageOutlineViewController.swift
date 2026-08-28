//
//  PageOutlineViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/6/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
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
    @IBOutlet weak var emptyMsg: NSTextField!

    // Built in code (see setupDuplicateButton): a compact button in the bottom bar next to the
    // add-page / add-section buttons that duplicates the current selection, plus the outline's
    // right-click menu. Both reuse the existing duplicate:/copy:/paste: commands.
    private var duplicateBtn: NSButton?
    
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
        setupDuplicateButton()
        setupContextMenu()
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
        
        emptyMsg.isHidden = pages!.count >= 1
        
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
                
                let type = page.type.uppercased().replacingOccurrences(of: "-", with: " & ")

                if page.type == PageTypes.QUIZ {

                    view?.pageTypeLbl.stringValue = type + " - " + Util.shared.getQuizType(type: page.quiz.type).uppercased()
                    view?.pageTypeLbl.toolTip = nil
                    view?.toolTip = nil

                } else {

                    // What a slide is missing, and whether it is captioned, are otherwise invisible
                    // from the outline — which is where someone checks a whole presentation before
                    // it ships, rather than opening sixty slides one at a time.
                    let captioned = hasCaptions(page)
                    let warnings = SlideWarning.warnings(for: inventory(for: page, hasCaptions: captioned))
                    let label = NSMutableAttributedString()

                    if !warnings.isEmpty {
                        label.append(SlideWarning.mark(baseFont: view?.pageTypeLbl.font))
                    }

                    label.append(CaptionBadge.typeLabel(
                        type,
                        state: CaptionBadge.state(pageType: page.type, hasCaptions: captioned),
                        baseFont: view?.pageTypeLbl.font
                    ))

                    view?.pageTypeLbl.attributedStringValue = label

                    // On the label and on the row both: the label sits over the row and would
                    // otherwise swallow the pointer without saying anything.
                    let tooltip = SlideWarning.tooltip(for: warnings)
                    view?.pageTypeLbl.toolTip = tooltip
                    view?.toolTip = tooltip

                }
                
                view?.pageTypeLbl.isHidden = false
                
            } else {

                view?.pageNumberLbl.stringValue = page.type.uppercased().replacingOccurrences(of: "-", with: " & ") + " \(page.number + 1)"
                view?.pageTypeLbl.isHidden = true

                // Cells are recycled, so a section header would otherwise keep whatever a slide row
                // left behind — "This slide has no image." on a row that holds no slide.
                view?.pageTypeLbl.toolTip = nil
                view?.toolTip = nil

            }
            
            view?.pageTitleLbl.stringValue = page.title
            
        }
        
        return view
        
    }

    /// What the presentation actually holds for a slide. A bundle's images are numbered from its
    /// source name ("sb03-1"), so its first frame is what says whether it has any at all.
    private func inventory(for page: Page, hasCaptions: Bool) -> SlideInventory {

        let imageFormat = currentDocument?.getXmlObj().pageImgFormat ?? ""
        let imageName = page.type == PageTypes.BUNDLE ? "\(page.src)-1.\(imageFormat)" : "\(page.src).\(imageFormat)"

        func holds(_ fileName: String, in directory: String) -> Bool {

            guard !page.src.isEmpty else { return false }

            return currentDocument?.fileExistsInAssetsDir(fileName: fileName,
                                                          subDirName: directory,
                                                          asBool: true) as? Bool ?? false

        }

        return SlideInventory(type: page.type,
                              src: page.src,
                              hasImage: holds(imageName, in: FileNames.PAGES_DIR),
                              hasAudio: holds("\(page.src).\(FileExtensions.MP3)", in: FileNames.AUDIO_DIR),
                              hasVideo: holds("\(page.src).\(FileExtensions.MP4)", in: FileNames.VIDEO_DIR),
                              hasCaptions: hasCaptions)

    }

    private func hasCaptions(_ page: Page) -> Bool {

        guard let directory = CaptionTrack.assetDirectory(forPageType: page.type), !page.src.isEmpty else { return false }

        return currentDocument?.fileExistsInAssetsDir(fileName: CaptionTrack.fileName(forPageSource: page.src),
                                                      subDirName: directory,
                                                      asBool: true) as? Bool ?? false

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

        // The selection lands on the moved row only after this method returns (via selectRowIndexes
        // below), so tell the undo machinery explicitly where redo should put it.
        let rowAfterMove = (dragAndDropIndice.first.map { $0 < index } ?? false) ? index - 1 : index

        currentDocument!.performUndoableStructuralChange(actionName: "Move Page", selectionAfter: [max(0, rowAfterMove)]) {

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

        }

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
        insertClipboard(data, atFlatIndex: insertIndex, actionName: "Paste")

    }

    // Duplicate the selected section(s)/page(s) in place: build the same independent-copy payload the
    // clipboard uses, then insert it right after the selection — no pasteboard involved.
    @objc func duplicate(_ sender: Any?) {

        let selected = pageOutlineView.selectedRowIndexes
        guard !selected.isEmpty else { return }
        guard let data = currentDocument?.makePagesClipboardData(forFlatRows: selected) else { return }

        insertClipboard(data, atFlatIndex: selected.last! + 1, actionName: "Duplicate")

    }

    // Insert a clipboard/duplicate payload at the given flat row, then select the inserted pages.
    private func insertClipboard(_ data: Data, atFlatIndex insertIndex: Int, actionName: String) {

        guard let count = currentDocument?.insertClipboardData(data, atFlatIndex: insertIndex, undoActionName: actionName), count > 0 else { return }

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

        currentDocument!.performUndoableStructuralChange(actionName: "Add Section") {
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
            currentDocument!.currentPageIndex = [newIndex]
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

        currentDocument!.performUndoableStructuralChange(actionName: "Add Page") {
            if let selected = pageOutlineView.selectedRowIndexes.last {
                currentDocument!.addSbPage(page: page, index: selected + 1)
                newIndex = selected + 1
            } else {
                currentDocument!.addSbPage(page: page)
                newIndex = pages!.count
            }
            currentDocument!.currentPageIndex = [newIndex]
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

        // Pinned to a row that exists. Deleting the first row asked for row -1, and deleting the last
        // one asked for a row the shorter outline no longer has; either is a range exception from
        // NSTableView rather than a misplaced selection.
        let landing = max((selectedIndexes.first ?? 0) - 1, 0)

        if pageOutlineView.numberOfRows > 0 {
            let row = min(landing, pageOutlineView.numberOfRows - 1)
            pageOutlineView.scrollRowToVisible(row)
            pageOutlineView.selectRowIndexes([row], byExtendingSelection: false)
        }
        
    }
    
    /*** PRIVATE METHODS ***/
    
    private func disableDeleteBtn() {
        deleteBtn.isEnabled = false
        deleteBtn.state = .off
        deleteBtn.contentTintColor = .controlColor
        duplicateBtn?.isEnabled = false
        NotificationCenter.default.post(name: Notification.Name("deleteBtnStateChanged"), object: nil, userInfo: ["enabled":false])
    }

    private func enableDeleteBtn() {
        deleteBtn.isEnabled = true
        deleteBtn.state = .on
        deleteBtn.contentTintColor = .systemRed
        duplicateBtn?.isEnabled = true
        NotificationCenter.default.post(name: Notification.Name("deleteBtnStateChanged"), object: nil, userInfo: ["enabled":true])
    }

    // Adds a compact "Duplicate" button to the bottom button bar, sitting just to the right of the
    // add-page / add-section buttons. It shares the delete button's enable/disable rule (a page
    // must be selected) and fires the same duplicate: command as Edit ▸ Duplicate and the right-click menu.
    private func setupDuplicateButton() {

        guard let container = deleteBtn.superview else { return }

        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.image = NSImage(systemSymbolName: "plus.square.on.square", accessibilityDescription: "Duplicate")
        button.toolTip = "Duplicate selected page(s)"
        button.target = self
        button.action = #selector(duplicate(_:))

        container.addSubview(button)

        // Match the add-page / add-section buttons it sits beside: same height and vertical center,
        // a square (icon-only) footprint, tucked in right after the Section button.
        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: addSectionBtn.centerYAnchor),
            button.heightAnchor.constraint(equalTo: addSectionBtn.heightAnchor),
            button.widthAnchor.constraint(equalTo: button.heightAnchor),
            button.leadingAnchor.constraint(equalTo: addSectionBtn.trailingAnchor, constant: 8)
        ])

        duplicateBtn = button
        duplicateBtn?.isEnabled = false

    }

    // Right-click menu on the page outline: Duplicate / Copy / Paste. Items reuse the existing
    // first-responder commands and are enabled/disabled by validateMenuItem(_:).
    private func setupContextMenu() {

        let menu = NSMenu()

        let duplicateItem = NSMenuItem(title: "Duplicate", action: #selector(duplicate(_:)), keyEquivalent: "")
        duplicateItem.target = self
        menu.addItem(duplicateItem)

        menu.addItem(NSMenuItem.separator())

        let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: "Paste", action: #selector(paste(_:)), keyEquivalent: "")
        pasteItem.target = self
        menu.addItem(pasteItem)

        pageOutlineView.menu = menu

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
            
            // Bounds-checked: this restores a selection captured in an undo snapshot, and undoing or
            // redoing a delete hands back a row number from an outline of a different length.
            if let index = index, index >= 0, index < pageOutlineView.numberOfRows {
                pageOutlineView.selectRowIndexes(NSIndexSet(index: index) as IndexSet, byExtendingSelection: false)
                pageOutlineView.scrollRowToVisible(index)
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

            // The stored index can outlive the row it named — an async redraw arriving after the
            // outline shrank — and item(atRow:) past the end is not a safe call.
            guard let row = currentDocument!.currentPageIndex.first,
                  row >= 0, row < pageOutlineView.numberOfRows else { return }

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

                // A presentation can legitimately open with no rows at all — every slide deleted, or
                // a new one set to start with none — and selecting row 0 of an empty outline throws.
                if pageOutlineView.numberOfRows > 0 {
                    pageOutlineView.selectRowIndexes([0], byExtendingSelection: false)
                    document.currentPageIndex = [0]
                } else {
                    document.currentPageIndex = []
                }

            }
            
        }
        
    }

    
}
