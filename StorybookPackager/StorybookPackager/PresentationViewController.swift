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

class PresentationViewController: NSViewController {
    
    private var document: Document?
    
    @IBOutlet weak var pageDetailsView: NSCollectionView!
    @IBOutlet weak var pageCollectionView: NSCollectionView!
    @IBOutlet weak var setupView: SbSetupView!

    var presentation: PresentationMeta = PresentationMeta()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
    }
    
    override func viewWillAppear() {
        document = NSDocumentController.shared.currentDocument as? Document
        checkPresentationLocation()
    }
    
    override func viewDidAppear() {
        
        do {
            
            let newXml:XMLDocument = try XMLDocument(xmlString: "<?xml version=\"1.0\" encoding=\"UTF-8\"?><storybook><setup><title>Hello World 2</title><subtitle></subtitle></setup></storybook>", options: [.documentTidyXML])
            
            document?.setXmlDoc(xmlStr: newXml.xmlString(options: [.nodeCompactEmptyElement, .nodePrettyPrint]))
            
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        
    }
    
    private func checkPresentationLocation() {
        
        let docLocation = NSDocumentController.shared.currentDocument?.fileURL
        
        if (docLocation == nil) {

            if let createPresentationController = self.storyboard?.instantiateController(withIdentifier: WindowIdentifiers.newPresentation) as? NewPresentationDialogController {

                createPresentationController.completionHandler = { (result) -> () in

                    if ( result.completed ) {

                        // set results to presentation object
                        self.presentation = result.presentationMeta
                        //print(self.presentation as Any)
                        
                        // show presentation setup side panel
                        // and set any carried over data
                        self.setupView.isHidden = false
                        self.setupView.titleTxtFld.stringValue = self.presentation.presenationTitle
                        
                        // load the middle panel with specified number of page counts
                        self.pageCollectionView.reloadData()

                    } else {

                        self.view.window?.close()

                    }

                }

                self.presentAsSheet(createPresentationController)

            }

        } else {
            
            print(document?.getXmlDoc().xmlString as Any)

        }
        
    }
    
}

extension PresentationViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageViewItem"), for: indexPath) as! PageViewItem
            
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
            return 1
        }
        
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if (collectionView.identifier!.rawValue == "pages") {
            
            return presentation.slideCount
            
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
