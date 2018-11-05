//
//  PageViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 11/1/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class PageViewItem: NSCollectionViewItem {

    @IBOutlet var container: NSView!
    @IBOutlet weak var headerBoxer: NSBox!
    
    private var pointingHand: NSCursor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        container.wantsLayer = true
        container.layer?.borderWidth = PageCell.borderWidth
        container.layer?.borderColor = PageCell.borderColor
        
    }
    
}
