//
//  PageEditViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/7/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class PageEditViewController: NSViewController, NSCollectionViewDataSource {
    
    @IBOutlet weak var pageEditScroller: NSScrollView!
    @IBOutlet weak var pageEditView: NSCollectionView!
    @IBOutlet weak var noPageSelectedBox: NSBox!
    @IBOutlet weak var multiPagesSelectedBox: NSBox!
    
    private var currentDocument: Document?
    private var pages: Array<Page>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.projectLoaded), name: Notification.Name("projectLoaded"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadPageEdit), name: Notification.Name("pageSelected"), object: nil)
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        currentDocument = NSDocumentController.shared.currentDocument as? Document
    }
    
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
    }
    
    /*** PUBLIC METHODS ***/
    
    func clearPageDetails() {
        pageEditView.reloadData()
    }
    
    /*** OBJECTIVE-C METHODS ***/
    
    @objc func reloadPageEdit(_ sender: NSNotification) {
        
        guard let document = sender.object as? Document else { return }
        
        if (document == currentDocument!) {
            pages = document.getXmlObjPages()
            pageEditView.reloadData()
        }
        
    }
    
    @objc func projectLoaded(_ sender: Notification) {
        
        self.view.isHidden = false
        
        // get all Storybook pages from current document
        guard let document = sender.object as? Document else { return }
        
        if (document == currentDocument!) {
            pages = document.getXmlObjPages()
        }
        
    }
    
    /*** PROTOCOLS TO SETUP PAGE COLLECTION DATA SOURCE ***/
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        
        guard let count = currentDocument?.currentPageIndex.count else { return 0 }
        
        if currentDocument!.currentPageIndex.first != -1 {
            
            if count == 1 {
                
                noPageSelectedBox.isHidden = true
                multiPagesSelectedBox.isHidden = true
                pageEditScroller.isHidden = false
                return 1
                
            } else if count > 1 {
                
                noPageSelectedBox.isHidden = true
                multiPagesSelectedBox.isHidden = false
                pageEditScroller.isHidden = true
                return 0
                
            }
            
        }
        
        noPageSelectedBox.isHidden = false
        multiPagesSelectedBox.isHidden = true
        pageEditScroller.isHidden = true
        return 0

    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        guard let index = currentDocument!.currentPageIndex.first else { return NSCollectionViewItem() }
        guard let page = pages?[index] else { return NSCollectionViewItem() }
        
        switch page.type {
            
        case PageTypes.SECTION:
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.SECTION_VIEW_ITEM), for: indexPath) as! SectionViewItem
            
            item.document = currentDocument!
            
            return item
            
        case PageTypes.KALTURA:
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.KALTURA_VIEW_ITEM), for: indexPath) as! KalturaViewItem
            
            item.document = currentDocument!
            
            return item
            
        case PageTypes.IMAGE:
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.IMAGE_VIEW_ITEM), for: indexPath) as! ImageViewItem
            
            item.document = currentDocument!
            
            return item
            
        case PageTypes.IMAGE_AUDIO:
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.IMAGE_AUDIO_VIEW_ITEM), for: indexPath) as! ImageAudioViewItem
            item.document = currentDocument!
            
            return item
            
        case PageTypes.YOUTUBE:
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.YOUTUBE_VIEW_ITEM), for: indexPath) as! YoutubeViewItem
            
            item.document = currentDocument!
            
            return item
            
        case PageTypes.VIMEO:
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.VIMEO_VIEW_ITEM), for: indexPath) as! VimeoViewItem
            
            item.document = currentDocument!
            
            return item
            
        case PageTypes.VIDEO:
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.VIDEO_VIEW_ITEM), for: indexPath) as! VideoViewItem
            
            item.document = currentDocument!
            
            return item
            
        default:
            
            return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.EMPTY), for: indexPath) as! EmptyViewItem
            
        }
        
    }
    
}
