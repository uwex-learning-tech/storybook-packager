//
//  SectionViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/13/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class SectionViewItem: NSCollectionViewItem {

    @IBOutlet weak var titleTxtfld: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    private var doc: Document?
    private var currentSectionObj: Section?
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        doc = (NSDocumentController.shared.currentDocument as? Document)!
        let currentPageObj = doc!.getXmlObj().getSectionAsPages()[doc!.currentPageIndex.item]
        
        currentSectionObj = doc!.getXmlObj().sections[currentPageObj.num]
        
    }
    
    @IBAction func onTitleChange(_ sender: NSTextField) {
        
        if (sender.stringValue != currentSectionObj!.title) {
            
            currentSectionObj!.title = sender.stringValue
            doc!.updateChangeCount(.changeDone)
            (NSApplication.shared.mainWindow?.contentViewController as? PresentationViewController)!.updatePages()
            
        }
        
    }
}
