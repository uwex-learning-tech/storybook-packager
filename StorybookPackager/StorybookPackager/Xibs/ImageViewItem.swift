//
//  PageDetailsViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/3/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class ImageViewItem: NSCollectionViewItem, NSTextViewDelegate {
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var imgSrc: NSTextField!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var imageWell: NSImageView!
    @IBOutlet var notesTxtvw: NSTextView!
    @IBOutlet weak var pageNumLbl: NSTextField!
    @IBOutlet weak var hiddenPageIndex: NSTextField!
    
    private var doc: Document?
    private var currentPageObj: Page?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        notesTxtvw.delegate = self
        
    }
    
    override func viewWillAppear() {
        
        doc = (NSDocumentController.shared.currentDocument as? Document)!
        currentPageObj = doc!.getXmlObj().getSectionAsPages()[Int(hiddenPageIndex.stringValue)!]
        
        pageNumLbl.stringValue = "Page \(currentPageObj!.num): \(titleTxtfld.stringValue)"
        
    }
    
    override func viewDidAppear() {
        
        if !imgSrc.stringValue.isEmpty {
            
            let imgUrl = URL(fileURLWithPath: imgSrc.stringValue)
            
            do {
                
                if ( try imgUrl.checkResourceIsReachable()) {
                    imageWell.image = NSImage(byReferencing: imgUrl)
                }
                
            } catch let error as NSError {
                
                let alert = NSAlert()
                alert.messageText = "Image Error"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.beginSheetModal(for: NSApp.keyWindow!, completionHandler: nil)
                
            }
            
        }
        
    }
    
    @IBAction func titleChange(_ sender: NSTextField) {
        
        if (sender.stringValue != currentPageObj!.title) {
            
            pageNumLbl.stringValue = "Page \(currentPageObj!.num): \(titleTxtfld.stringValue)"
            
            currentPageObj?.title = sender.stringValue
            doc!.updateChangeCount(.changeDone)
            
            (NSApplication.shared.mainWindow?.contentViewController as? PresentationViewController)!.updatePages()
            
        }
        
    }
    
    @IBAction func browseImgSrc(_ sender: NSButton) {
        
        let fileType = "\((NSDocumentController.shared.currentDocument as? Document)!.getXmlObj().pageImgFormat)"
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = false
        imgBrowsePanel.canChooseDirectories = false
        imgBrowsePanel.allowedFileTypes = [fileType]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if (result == NSApplication.ModalResponse.OK) {
                
                self.imgSrc.stringValue = imgBrowsePanel.url!.absoluteString
                self.imageWell.image = NSImage(byReferencing: imgBrowsePanel.url!)
                (NSDocumentController.shared.currentDocument as? Document)!.updateChangeCount(.changeDone)
                
            }
            
        })
        
    }
    
    func textDidEndEditing(_ notification: Notification) {
        
        guard let textView = notification.object as? NSTextView else { return }
        
        if (textView.string != currentPageObj!.notes) {
            currentPageObj?.notes = textView.string
        }
        
    }
    
}
