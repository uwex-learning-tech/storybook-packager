//
//  PageSectionItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/12/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class PageSectionItem: NSCollectionViewItem {
    
    
    @IBOutlet var container: CollectionItemContainer!
    @IBOutlet weak var titleLbl: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
    }
    
    override var isSelected: Bool {
        
        didSet {
            
            if (isSelected) {
                
                container.isSelected = true
                container.needsDisplay = true
                
            } else {
                
                container.isSelected = false
                container.needsDisplay = true
                
            }
            
        }
        
    }

}
