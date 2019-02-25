//
//  AssetsViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/8/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class AssetsViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    @IBOutlet weak var assetsOutline: FilesOutlineView!
    
    let assetManager = FileManager.default
    let assetUrl = URL(fileURLWithPath: "\(NSDocumentController.shared.currentDirectory!)/\((NSDocumentController.shared.currentDocument as? Document)!.displayName!)/assets/")
    private var rootItem: FileItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // set view size
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height)
        rootItem = FileItem(url: assetUrl, parent: nil, isLeaf: true, icon: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        assetsOutline.expandItem(rootItem)
        
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
        
        var view: FilesTableCellView?
        
        view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "FeedCell"), owner: self) as? FilesTableCellView
        
        if let file = item as? FileItem {
            
            view?.name.stringValue = file.name
            view?.icon.image = file.icon
            
        } else {
            
            view?.name.stringValue = self.rootItem!.name
            view?.icon.image = self.rootItem!.icon
            
        }
        
        return view
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
        
        if let file = item as? FileItem {
            if file.name == rootItem!.name {
                return false
            }
        }
        
        return true
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        
        if let file = item as? FileItem {
            if file.name == rootItem!.name {
                return false
            }
        }
        
        return true
        
    }
    
//    func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
//        
//        print("expand")
//        
//        if let file = item as? FileItem {
//            if file.name == rootItem!.name {
//                return true
//            }
//        }
//        
//        return false
//        
//    }
    
}
