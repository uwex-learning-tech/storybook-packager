//
//  PageDetailsViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/3/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser
import WebKit

class ImageViewItem: NSCollectionViewItem, NSTextViewDelegate, NSTextFieldDelegate {
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var imageWell: NSImageView!
    @IBOutlet weak var svgView: WKWebView!
    @IBOutlet weak var notesTxtvw: NSTextView!
    @IBOutlet weak var pageNumLbl: NSTextField!
    
    private var doc: Document?
    private var currentPageObj: Page?
    private var fileType: String?
    private let prefSettings = UserDefaults.standard
    
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
        
        if (fileType! == FileExtensions.SVG) {
            
            imageWell.isHidden = true
            svgView.isHidden = false
            
        } else {
            
            imageWell.isHidden = false
            svgView.isHidden = true
            
        }
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if !currentPageObj!.src.isEmpty {
            
            if let imgFile = doc!.getAssetsWrapper(name: "\(currentPageObj!.src).\(fileType!)", at: FileNames.PAGES_DIR) {
                
                if (fileType! == FileExtensions.SVG) {
                    
                    let svg = String(data: imgFile.regularFileContents!, encoding: String.Encoding.utf8)
                    self.svgView.loadHTMLString(Util.shared.formatSvg(str: svg!), baseURL: URL(string: "http://localhost"))
                    
                } else {
                    
                    imageWell.image = NSImage(data: imgFile.regularFileContents!)
                    
                }
                
            }
            
        } else {
            
            if (fileType! == FileExtensions.SVG) {
                
                let imgFileUrl = Bundle.main.url(forResource: ObjIdentifiers.PAGE_IMAGE_PLACEHOLDER, withExtension: FileExtensions.PNG)?.absoluteURL
                let data = NSData(contentsOf: imgFileUrl!)?.base64EncodedString(options: NSData.Base64EncodingOptions.endLineWithLineFeed)
                self.svgView.loadHTMLString(Util.shared.formatImgHtml(base64: data!), baseURL: URL(string: "http://localhost"))
                
            }
            
        }
        
    }
    
    func controlTextDidChange(_ obj: Notification) {
        
        guard let tf = (obj.object as? NSTextField) else { return }
        
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(tf.stringValue)"
        
        currentPageObj?.title = tf.stringValue
        doc!.updateChangeCount(.changeDone)
        NotificationCenter.default.post(name: Notification.Name("reloadPageCollection"), object: nil, userInfo: ["refreshOnly":true])
        
    }
    
    @IBAction func browseImgSrc(_ sender: NSButton) {
        
        let fileType = "\((NSDocumentController.shared.currentDocument as? Document)!.getXmlObj().pageImgFormat)"
        self.openBrowsePanel(type: fileType)
        
    }
    
    private func openBrowsePanel(type: String) {
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = false
        imgBrowsePanel.canChooseDirectories = false
        imgBrowsePanel.allowedFileTypes = [type]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if (result == NSApplication.ModalResponse.OK) {
                
                if type == FileExtensions.SVG {
                    
                    do {
                        
                        let svg = try String(contentsOf: imgBrowsePanel.url!, encoding: String.Encoding.utf8)
                        self.svgView.loadHTMLString(Util.shared.formatSvg(str: svg), baseURL: URL(string: "http://localhost"))
                        
                    } catch let error as NSError {
                        
                        print(error.localizedDescription)
                        
                    }

                } else {
                    
                    self.imageWell.image = NSImage(byReferencing: imgBrowsePanel.url!)
                    
                }

                let doc = (NSDocumentController.shared.currentDocument as? Document)!
                let page = doc.getXmlObjPages()[doc.currentPageIndex.first!.item]
                let fileName = "\(self.prefSettings.string(forKey: Preferences.ASSET_FILE_NAME)!)\(Util.shared.formatPageNum(num: page.number + 1))"
                
                page.src = fileName
                doc.addAssetsWrappersFile(name: "\(fileName).\(type)", path: imgBrowsePanel.url!, to: FileNames.PAGES_DIR)
                doc.updateChangeCount(.changeDone)
                
            }
            
        } )
        
    }
    
    @IBAction func pageTypeChange(_ sender: NSPopUpButton) {
        
        let type = Util.shared.formatPageTypeString(string: sender.selectedItem!.title)
        
        guard type != self.currentPageObj!.type else { return }
        
        self.currentPageObj!.type = type
        doc!.updateChangeCount(.changeDone)
        
        NotificationCenter.default.post(name: Notification.Name("reloadPageCollection"), object: nil, userInfo: ["refreshOnly":false])
        
    }
    
}
