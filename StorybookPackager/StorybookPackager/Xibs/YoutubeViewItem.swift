//
//  YoutubeViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 1/17/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser
import WebKit

class YoutubeViewItem: NSCollectionViewItem, NSTextViewDelegate, NSTextFieldDelegate {
    
    @IBOutlet weak var pageNumLbl: NSTextField!
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var videoIdTxtfld: NSTextField!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var notesTxtvw: NSTextView!
    
    private var doc: Document?
    private var currentPageObj: Page?
    private var fileType: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        notesTxtvw.delegate = self
        titleTxtfld.delegate = self
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        doc = (NSDocumentController.shared.currentDocument as? Document)!
        currentPageObj = doc!.getXmlObjPages()[doc!.currentPageIndex.first!.item]
        fileType = doc!.getXmlObj().pageImgFormat
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(currentPageObj!.title)"
        titleTxtfld.stringValue = currentPageObj!.title
        notesTxtvw.string = currentPageObj!.notes
        typeBtn.selectItem(at: Util.shared.getPageTypeIndex(type: currentPageObj!.type, collection: typeBtn.itemTitles))
        
        videoIdTxtfld.stringValue = currentPageObj!.src
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if !currentPageObj!.src.isEmpty {

            self.webView.loadHTMLString(Util.shared.formatIframe(str: currentPageObj!.src, type: PageTypes.YOUTUBE), baseURL: URL(string: "http://localhost"))
            
        }
        
    }
    
    func controlTextDidChange(_ obj: Notification) {
        
        guard let tf = (obj.object as? NSTextField) else { return }
        
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(tf.stringValue)"
        
        currentPageObj?.title = tf.stringValue
        doc!.updateChangeCount(.changeDone)
        NotificationCenter.default.post(name: Notification.Name("reloadPageCollection"), object: nil, userInfo: ["refreshOnly":true])
        
    }
    
    @IBAction func videoIdChange(_ sender: NSTextField) {
        
        if (sender.stringValue != currentPageObj!.src) {
            
            self.webView.loadHTMLString(Util.shared.formatIframe(str: sender.stringValue, type: PageTypes.YOUTUBE), baseURL: URL(string: "http://localhost"))
            
            currentPageObj?.src = sender.stringValue
            doc!.updateChangeCount(.changeDone)
            
        }
        
    }
    
    @IBAction func pageTypeChange(_ sender: NSPopUpButton) {
        
        let type = Util.shared.formatPageTypeString(string: sender.selectedItem!.title)
        
        guard type != self.currentPageObj!.type else { return }
        
        self.currentPageObj!.type = type
        doc!.updateChangeCount(.changeDone)
        
        NotificationCenter.default.post(name: Notification.Name("reloadPageCollection"), object: nil, userInfo: ["refreshOnly":false])
        
    }
    
}
