//
//  AssetsViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/8/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class AssetsViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    @IBOutlet weak var assetsOutline: NSOutlineView!
    
    let assetManager = FileManager.default
    let assetUrl = URL(fileURLWithPath: "\(NSDocumentController.shared.currentDirectory!)/\((NSDocumentController.shared.currentDocument as? Document)!.displayName!)/assets/")
    private var rootItem: FileItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        rootItem = FileItem(url: assetUrl, parent: nil, isLeaf: true)
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        
        if let file = item as? FileItem {
            return file.count
        }
        
        return 1
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        
        if let file = item as? FileItem {
            return file.child(atIndex: index)!
        }
        
        return rootItem!
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        
        if let file = item as? FileItem {
            if file.count > 0 {
                return true
            }
        }
        
        return false
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        
        var view: NSTableCellView?
        
        view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "FeedCell"), owner: self) as? NSTableCellView
        
        if let file = item as? FileItem {
            if let textField = view?.textField {
                textField.stringValue = file.name
                textField.sizeToFit()
            }
        } else {
            if let textField = view?.textField {
                textField.stringValue = self.rootItem!.name
                textField.sizeToFit()
            }
        }
        
        return view
        
    }
    
}
