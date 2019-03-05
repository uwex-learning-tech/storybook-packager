//
//  ImportViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/28/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class ImportViewController: NSViewController {
    
    var doc: Document?
    var expectedExt = [FileExtensions.MP3, FileExtensions.MP4]
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        doc = NSDocumentController.shared.currentDocument as? Document
        expectedExt.append(doc!.getXmlObj().pageImgFormat)
    }
    
    
    
}
