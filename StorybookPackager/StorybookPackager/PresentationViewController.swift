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
    private var pageCount = 0;
    @IBOutlet weak var pageDetailsView: NSCollectionView!
    @IBOutlet weak var pageCollectionScroller: NSScrollView!
    @IBOutlet weak var pageCollectionView: NSCollectionView!
    @IBOutlet weak var setupView: SbSetupView!

    var presentation: PresentationMeta = PresentationMeta()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        pageCollectionScroller.scrollerStyle = .overlay
        
    }
    
    override func viewWillAppear() {
        document = NSDocumentController.shared.currentDocument as? Document
    }
    
    override func viewDidAppear() {
        
        setPresentation()
        
    }
    
    private func setPresentation() {
        
        if (self.document?.fileURL == nil) {

            if let createPresentationController = self.storyboard?.instantiateController(withIdentifier: WindowIdentifiers.newPresentation) as? NewPresentationDialogController {

                createPresentationController.completionHandler = { (result) -> () in

                    if ( result.completed ) {
                        
                        // set results to presentation object
                        self.presentation = result.presentationMeta
                        //print(self.presentation as Any)
                        self.dismiss(createPresentationController)
                        self.openSavePanel()

                    } else {
                        
                        self.dismiss(createPresentationController)
                        self.view.window?.close()

                    }

                }

                self.presentAsSheet(createPresentationController)

            }

        } else {
            
            let xmlParser = SbXmlParser()
            self.sbXml = xmlParser.parse(xmlString: (self.document?.getXmlDoc().xmlString)!)
            
            self.presentation.presenationTitle = self.sbXml!.setup.title
            self.presentation.program = self.sbXml!.setup.program
            self.presentation.courseCode = self.sbXml!.setup.course
            
            setFields()
            //print(document?.getXmlDoc().xmlString as Any)

        }
        
    }
    
    private func openSavePanel() {
        
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
                
                var setup: Setup = Setup()
                setup.title = self.presentation.presenationTitle
                setup.program = self.presentation.program
                setup.course = self.presentation.courseCode
                
                var sections: Array<Section> = Array()
                var section = Section()
                let pages: Array<Page> = Array(repeating: Page(), count: self.presentation.slideCount)
                
                section.pages = pages
                sections.append(section)
                
                self.sbXml = StorybookXml(
                    accent: self.setupView.accentColorTxtFld.stringValue,
                    imgFormat: self.setupView.pageImgTypePBtn.stringValue,
                    splashFormat: self.setupView.splashImgTypePBtn.stringValue,
                    analytics: self.setupView.analyticsOnCb.state == .on ? true : false,
                    mathJax: self.setupView.mathjaxOnCb.state == .on ? true : false,
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
        
    }
    
    @objc func docDidSave(_ doc: NSDocument?, didSave: Bool, contextInfo: UnsafeMutableRawPointer?) {
        
        setFields()
        
    }
    
    private func setFields() {
        
        // show presentation setup side panel
        // and set any carried over data
        self.setupView.isHidden = false
        self.setupView.titleTxtFld.stringValue = self.presentation.presenationTitle
        
        // load the middle panel with specified number of page counts
        self.pageCollectionView.reloadData()
        
    }
    
}

extension PresentationViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageViewItem"), for: indexPath) as! PageViewItem
            
            self.pageCount += 1
            
            let sectionIndex = indexPath.section
            let pageIndex = indexPath.item
            
            item.typeLbl.stringValue = self.sbXml!.sections[sectionIndex].pages![pageIndex].type.uppercased()
            item.countLbl.stringValue = "\(self.pageCount)"
            item.titleLbl.stringValue = self.sbXml!.sections[sectionIndex].pages![pageIndex].title
            
            return item
            
        } else  {
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "VideoViewItem"), for: indexPath) as! VideoViewItem
            
            item.pageTitle?.stringValue = ""
            
            guard let url = URL(string: "file:///Users/ethan.lin/Desktop/GitHub/sbplus_v3/build/assets/video/smgt370_course_intro.mp4") else { return item }
            
            let player = AVPlayer(url: url)
            
            item.mediaPreview?.player = player
            
            return item
            
        }
        
    }
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            guard let num = self.sbXml?.sections.count else {
                return 0
            }

            return num
            
        }
        
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            guard let num = self.sbXml?.sections[section].pages?.count else {
                return 0
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
            
            return CGSize(width: pageCollectionView.bounds.width - 22, height: PageViewItem().view.bounds.height)
            
        } else {
            
            return CGSize(width: pageDetailsView.bounds.width, height: VideoViewItem().view.bounds.height)
            
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
