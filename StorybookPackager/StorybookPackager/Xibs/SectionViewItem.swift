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
    @IBOutlet weak var sectionHeadTitle: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    private var currentPageObj: Page?
    private var doc: Document?
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        doc = (NSDocumentController.shared.currentDocument as? Document)!
        currentPageObj = doc!.getXmlObjPages()[doc!.currentPageIndex.item]
        
        sectionHeadTitle.stringValue = "Section \(currentPageObj!.number + 1)\(currentPageObj!.title.isEmpty ? "" : ": \(currentPageObj!.title)")"
        
    }
    
    @IBAction func onTitleChange(_ sender: NSTextField) {
        
        if (sender.stringValue != currentPageObj!.title) {
            
            currentPageObj!.title = sender.stringValue
            sectionHeadTitle.stringValue = "Section \(currentPageObj!.number + 1): \(sender.stringValue)"
            
            doc!.updateChangeCount(.changeDone)
            (NSApplication.shared.mainWindow?.contentViewController as? PresentationViewController)!.updatePage()
            
        }
        
    }
}
