//
//  SectionViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/13/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class SectionViewItem: NSCollectionViewItem, NSTextFieldDelegate {

    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var sectionHeadTitle: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        titleTxtfld.delegate = self
    }
    
    var document: Document?
    private var currentPageObj: Page?
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        //document = (NSDocumentController.shared.currentDocument as? Document)!
        currentPageObj = document!.getXmlObjPages()[document!.currentPageIndex.first!.item]
        titleTxtfld.stringValue = currentPageObj!.title
        sectionHeadTitle.stringValue = "Section \(currentPageObj!.number + 1)\(currentPageObj!.title.isEmpty ? "" : ": \(currentPageObj!.title)")"
        
    }
    
    func controlTextDidChange(_ obj: Notification) {
        
        guard let tf = (obj.object as? NSTextField) else { return }
        
        sectionHeadTitle.stringValue = "Section \(currentPageObj!.number + 1): \(tf.stringValue)"
        
        currentPageObj?.title = tf.stringValue
        document!.updateChangeCount(.changeDone)
        NotificationCenter.default.post(name: Notification.Name("reloadPageCollection"), object: document!, userInfo: ["refreshOnly":true])
        
    }
    
}
