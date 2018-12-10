//
//  PresentationViewController.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit
import SbXmlParser

class PresentationViewController: NSViewController {
    
    private var document: Document?
    private var sbXml: StorybookXml?
    private var pages: Array<Page>?
    private var pageCount = 0;
    @IBOutlet weak var pageDetailsScroller: NSScrollView!
    @IBOutlet weak var pageDetailsView: NSCollectionView!
    @IBOutlet weak var pageCollectionScroller: NSScrollView!
    @IBOutlet weak var pageCollectionView: NSCollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do view setup here.
        pageDetailsScroller.scrollerStyle = .overlay
        pageCollectionScroller.scrollerStyle = .overlay
        
    }
    
    override func viewWillAppear() {
        document = NSDocumentController.shared.currentDocument as? Document
    }
    
    override func viewDidAppear() {
        
        self.openSavePanel()

    }
    
    private func openSavePanel() {
        
        if (self.document?.fileURL == nil) {
            
            let savePanel = NSSavePanel()
            
            savePanel.prompt = "Create"
            savePanel.nameFieldLabel = "Project Name:"
            savePanel.allowedFileTypes = ["sbproj"]
            savePanel.treatsFilePackagesAsDirectories = false
            savePanel.canCreateDirectories = true
            savePanel.isExtensionHidden = false
            savePanel.canSelectHiddenExtension = true
            
            savePanel.beginSheetModal(for: self.view.window!, completionHandler: { result in
                
                if result == NSApplication.ModalResponse.OK {
                    
                    guard let saveUrl = savePanel.url else { return }
                    
                    let setup: Setup = Setup()
                    //setup.title = self.presentation.presenationTitle
                    //setup.program = self.presentation.program
                    //setup.course = self.presentation.courseCode
                    
                    var sections: Array<Section> = Array()
                    var section = Section()
                    let pages: Array<Page> = Array(repeating: Page(), count: 1)
                    
                    section.pages = pages
                    sections.append(section)
                    
                    self.sbXml = StorybookXml(
                        accent: "", //self.setupView.accentColorTxtFld.stringValue,
                        imgFormat: "", //self.setupView.pageImgTypePBtn.stringValue,
                        splashFormat: "", //self.setupView.splashImgTypePBtn.stringValue,
                        analytics: false, //self.setupView.analyticsOnCb.state == .on ? true : false,
                        mathJax: false, //self.setupView.mathjaxOnCb.state == .on ? true : false,
                        setup: setup,
                        sections: sections,
                        xmlVersion: "3.0")
                    
                    do {
                        
                        let newXml:XMLDocument = try XMLDocument(xmlString: self.sbXml!.toString(), options: [.documentTidyXML])
                        
                        self.document?.setXmlDoc(xmlStr: newXml.xmlString(options: [.nodeCompactEmptyElement, .nodePrettyPrint]))
                        self.document?.save(to: saveUrl, ofType: (self.document?.fileType)!, for: NSDocument.SaveOperationType.saveOperation, delegate: self, didSave: #selector(self.docDidSave), contextInfo: nil)
                        
                    } catch let error as NSError {
                        print(error.localizedDescription)
                    }
                    
                } else {
                    
                    self.view.window?.close()
                    
                }
                
            })
            
        } else {
            
            let xmlParser = SbXmlParser()
            self.sbXml = xmlParser.parse(xmlString: (self.document?.getXmlDoc().xmlString)!)
            //print(document?.getXmlDoc().xmlString as Any)
            
            setFields()
            
        }
        
    }
    
    @objc func docDidSave(_ doc: NSDocument?, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        
        self.displayPropertiesDialog()
        
    }
    
    private func displayPropertiesDialog() {
        
        if let propertiesDialogController = self.storyboard?.instantiateController(withIdentifier: WindowIdentifiers.PROPERTIES_DIALOG) as? PropertiesDialogController {
            
            propertiesDialogController.completionHandler = { (result) -> () in
                
                self.dismiss(propertiesDialogController)
                self.setFields()
                
            }
            
            self.presentAsSheet(propertiesDialogController)
            
        }
        
    }
    
    private func setFields() {
        
        self.pages = self.sbXml?.getSectionAsPages()
        
        self.pageDetailsScroller.isHidden = false
        
        // load the middle panel with specified number of page counts
        self.pageCollectionView.reloadData()
        
    }
    
}

extension PresentationViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            let item: PageViewItem
            let index = indexPath.item
            
            if (self.pages![index].type != "section") {
                
                item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageViewItem"), for: indexPath) as! PageViewItem
                
                self.pageCount += 1
                
                item.typeLbl.stringValue = self.pages![index].type.uppercased()
                item.countLbl.stringValue = "\(self.pageCount)"
                item.titleLbl.stringValue = self.pages![index].title
                
            } else {
                
                item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageViewItem"), for: indexPath) as! PageViewItem
                
                item.typeLbl.stringValue = self.pages![index].type.uppercased()
                item.titleLbl.stringValue = self.pages![index].title
                
            }
            
            return item
            
        } else {
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "VideoViewItem"), for: indexPath) as! VideoViewItem
            
            item.pageTitle?.stringValue = ""
            
            guard let url = URL(string: "file:///Users/ethan.lin/Desktop/GitHub/sbplus_v3/build/assets/video/smgt370_course_intro.mp4") else { return item }
            
            let player = AVPlayer(url: url)
            
            item.mediaPreview?.player = player
            
            return item
            
        }
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {

        if (collectionView.identifier!.rawValue == "pages") {
            
            guard let num = self.pages?.count else {
                return 0;
            }

            return num

        } else {

            return 1

        }

    }
    
}

extension PresentationViewController: NSCollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            
            return CGSize(width: pageCollectionView.bounds.width - 20, height: PageViewItem().view.bounds.height)
            
        } else {

            return CGSize(width: pageDetailsView.bounds.width - 20, height: VideoViewItem().view.bounds.height)
            
        }
        
    }
    
    // select page cell
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        
        guard let item = collectionView.item(at: indexPaths.first!) as? PageViewItem else {
            return
        }
        
        item.container.layer?.borderWidth = PageCell.borderWidthSelected
        item.container.layer?.borderColor = PageCell.borderColorSelected
        
    }
    
    // unselect page cells
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        
        guard let item = collectionView.item(at: indexPaths.first!) as? PageViewItem else {
            return
        }
        
        item.container.layer?.borderWidth = PageCell.borderWidth
        item.container.layer?.borderColor = PageCell.borderColor
        
    }
    
}
