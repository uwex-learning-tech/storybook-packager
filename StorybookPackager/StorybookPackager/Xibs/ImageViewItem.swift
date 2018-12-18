//
//  PageDetailsViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/3/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class ImageViewItem: NSCollectionViewItem {
    

    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var imgSrc: NSTextField!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var imageWell: NSImageView!
    @IBOutlet var notesTxtvw: NSTextView!
    @IBOutlet weak var pageNumLbl: NSTextField!
    @IBOutlet weak var hiddenPageIndex: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        
    }
    
    override func viewWillAppear() {
        
        print(hiddenPageIndex.stringValue)
        
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
    
}
