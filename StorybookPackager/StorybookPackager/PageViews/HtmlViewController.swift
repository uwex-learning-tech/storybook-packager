//
//  HtmlViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 4/2/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class HtmlViewController: NSViewController {
    
    var currentDocument: Document?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    func setHtml() {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }
        
        print(currentPage.embed)
        
    }
    
}
