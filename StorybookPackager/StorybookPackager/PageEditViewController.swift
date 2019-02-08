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
    
    private var document: Document?
    private var pages: Array<Page>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.projectCreated), name: Notification.Name("projectCreated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadPageEdit), name: Notification.Name("reloadPageEdit"), object: nil)
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // get current document instance
        document = NSDocumentController.shared.currentDocument as? Document
        
    }
    
    /*** PUBLIC METHODS ***/
    
    func clearPageDetails() {
        pageEditView.reloadData()
    }
    
    /*** OBJECTIVE-C METHODS ***/
    
    @objc func reloadPageEdit(_ sender: NSNotification) {
        
        pages = document?.getXmlObjPages()
        pageEditView.reloadData()
        
    }
    
    @objc func projectCreated(_ sender: Notification) {
        self.view.isHidden = false
        
        // get all Storybook pages from current document
        pages = document?.getXmlObjPages()
    }
    
    /*** PROTOCOLS TO SETUP PAGE COLLECTION DATA SOURCE ***/
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        
        guard let count = document?.currentPageIndex.count else {
            noPageSelectedBox.isHidden = false
            multiPagesSelectedBox.isHidden = true
            pageEditScroller.isHidden = true
            return 0
        }
        
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
        } else {
            noPageSelectedBox.isHidden = false
            multiPagesSelectedBox.isHidden = true
            pageEditScroller.isHidden = true
            return 0
        }

    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        guard let index = document?.currentPageIndex.first?.item else { return NSCollectionViewItem() }
        guard let page = pages?[index] else { return NSCollectionViewItem() }
        
        switch page.type {
            
        case PageTypes.SECTION:
            
            return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.SECTION_VIEW_ITEM), for: indexPath) as! SectionViewItem
            
        case PageTypes.KALTURA:
            
            return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.KALTURA_VIEW_ITEM), for: indexPath) as! KalturaViewItem
            
        case PageTypes.IMAGE:
            
            return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.IMAGE_VIEW_ITEM), for: indexPath) as! ImageViewItem
            
        case PageTypes.IMAGE_AUDIO:
            
            return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.IMAGE_AUDIO_VIEW_ITEM), for: indexPath) as! ImageAudioViewItem
            
        case PageTypes.YOUTUBE:
            
            return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.YOUTUBE_VIEW_ITEM), for: indexPath) as! YoutubeViewItem
            
        case PageTypes.VIMEO:
            
            return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.VIMEO_VIEW_ITEM), for: indexPath) as! VimeoViewItem
            
        case PageTypes.VIDEO:
            
            return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.VIDEO_VIEW_ITEM), for: indexPath) as! VideoViewItem
            
        default:
            
            return collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: Xibs.EMPTY), for: indexPath) as! EmptyViewItem
            
        }
        
    }
    
}
