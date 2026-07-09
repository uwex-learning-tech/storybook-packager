//
//  WidgetsViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/14/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class WidgetsViewController: NSViewController, NSTextViewDelegate {
    
    @IBOutlet var widgetTxtVw: NSTextView!
    @IBOutlet weak var segmentTblVw: NSTableView!
    @IBOutlet weak var removeSegmentBtn: NSButton!
    
    var currentDocument: Document?
    var segments: Array<Segment> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // add inner padding to text area
        widgetTxtVw.isAutomaticQuoteSubstitutionEnabled = false
        widgetTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        widgetTxtVw.delegate = self
        
        segmentTblVw.delegate = self
        segmentTblVw.dataSource = self
        segmentTblVw.target = self
        segmentTblVw.selectionHighlightStyle = .regular
        
        // set the state of the add and remove segment buttons
        setRemoveBtnState()
        
        // add notification
        NotificationCenter.default.addObserver(self, selector: #selector(self.loadWidget), name: Notification.Name("loadWidget"), object: nil)
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        self.view.frame = self.view.superview!.frame
        currentDocument = NSDocumentController.shared.currentDocument as? Document
    }
    
    func resizeContentSize() {
        self.view.frame = self.view.superview!.frame
    }
    
    @IBAction func addSegement(_ sender: NSButton) {
        
        guard currentDocument != nil else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[currentDocument!.currentPageIndex.first!]
        var segment: Segment = Segment()
        
        segment.name = "New Segment"
        segment.content = ""
        
        currentPage.addSegment(segment: segment)
        
        segments = currentPage.widget
        
        segmentTblVw.reloadData()
        segmentTblVw.editColumn(0, row: segments.count - 1, with: nil, select: false)
        segmentTblVw.selectRowIndexes([segments.count - 1], byExtendingSelection: false)
        
        currentDocument!.updateChangeCount(.changeDone)
        setRemoveBtnState()
        
    }
    
    @IBAction func removeSegment(_ sender: NSButton) {
        
        if segmentTblVw.selectedRowIndexes.count >= 1 {
            
            guard currentDocument != nil else { return }
            
            let currentPage = currentDocument!.getXmlObjPages()[currentDocument!.currentPageIndex.first!]
            
            currentPage.widget.remove(at: segmentTblVw.selectedRowIndexes.first!)
            segments = currentPage.widget
            
            segmentTblVw.removeRows(at: segmentTblVw.selectedRowIndexes, withAnimation: NSTableView.AnimationOptions.slideUp)
            segmentTblVw.deselectAll(nil)
            
            setRemoveBtnState()
            
            currentDocument!.updateChangeCount(.changeDone)
            
        }
        
    }
    
    @IBAction func segmentCellTextChange(_ sender: NSTextField) {
        
        guard currentDocument != nil else { return }
        guard let currentIndex = currentDocument!.currentPageIndex.first else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[currentIndex]
        
        guard segmentTblVw.selectedRowIndexes.first != nil && currentPage.widget.indices.contains(segmentTblVw.selectedRowIndexes.first!) else { return }
        
        currentPage.widget[segmentTblVw.selectedRowIndexes.first!].name = sender.sanitize()
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    func textDidEndEditing(_ sender: Notification) {
        
        guard segmentTblVw.selectedRowIndexes.count >= 1 else { return }
        guard currentDocument != nil else { return }
        guard let textView = sender.object as? NSTextView else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        currentPage.widget[segmentTblVw.selectedRowIndexes.first!].content = textView.sanitize()
        segments = currentPage.widget
        
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    @objc func loadWidget(_ sender: Notification) {

        guard let document = sender.object as? Document else { return }
        guard currentDocument != nil else { return }
        
        if document == currentDocument! {
            
            widgetTxtVw.string = ""
            segments = document.getXmlObjPages()[document.currentPageIndex.first!].widget
            segmentTblVw.reloadData()
            segmentTblVw.selectRowIndexes([0], byExtendingSelection: false)
            setRemoveBtnState()
            
        }
        
    }
    
    private func setRemoveBtnState() {
        
        if (segmentTblVw.selectedRowIndexes.first) != nil {
            
            removeSegmentBtn.isEnabled = true
            
        } else {
            
            removeSegmentBtn.isEnabled = false
            widgetTxtVw.string = ""
            
        }

    }
    
}

extension WidgetsViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return segments.count
    }
    
}

extension WidgetsViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        if ( tableColumn == segmentTblVw.tableColumns[0] ) {
            
            if let cell = segmentTblVw.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ObjIdentifiers.SEGMENT_CELL), owner: self ) as? NSTableCellView {
                
                if row <= segments.count - 1 {
                    cell.textField?.stringValue = segments[row].name
                }
                
                return cell
                
            }
            
        }
        
        return NSTableCellView()
        
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        
        guard let index = segmentTblVw.selectedRowIndexes.first else { return }
        
        setRemoveBtnState()
        widgetTxtVw.string = segments[index].content
        
    }
    
}
