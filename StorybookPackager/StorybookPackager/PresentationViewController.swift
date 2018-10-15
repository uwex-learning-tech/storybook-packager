//
//  PresentationViewController.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import AVKit
import AVFoundation

class PresentationViewController: NSViewController {
    
    @IBOutlet weak var presentationSetupScrollView: NSScrollView!
    @IBOutlet weak var pageDetailsView: NSCollectionView!
    @IBOutlet weak var setupView: SbSetupView!

   var presentation: PresentationMeta = PresentationMeta()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
    }
    
    override func viewDidAppear() {
        
        if ( presentation.location.isEmpty ) {

            if let createPresentationController = self.storyboard?.instantiateController(withIdentifier: SegueIdentifiers.newPresentation) as? NewPresentationDialogController {

                createPresentationController.completionHandler = { (result) -> () in

                    if ( result.completed ) {

                        self.presentation = result.presentationMeta
                        print(self.presentation as Any)
                        
                        let recentProjectFile: URL = Util.shared.getRecentProjectsJsonFile()
                        
                        if (FileManager.default.fileExists(atPath: recentProjectFile.path) ) {
                            
                            let fileContent:String = Util.shared.read(path: recentProjectFile)
                            var projects: Array<URL> = Array(Util.shared.decodeRecentProjects(json: fileContent))
                            
                            if (projects.count == MaxLimit.recentProject) {
                                
                                projects.removeLast()
                                
                            }
                            
                            let projectLocation: URL = (URL(string: self.presentation.location)?.appendingPathComponent(self.presentation.projectName))!
                            
                            if (!projects.contains(projectLocation)) {
                                
                                projects.insert(projectLocation, at: 0)
                                Util.shared.writeToFile(path: recentProjectFile, content: Util.shared.encodeRecentProjects(obj: projects))
                                
                            }

                        }
                        
                        //self.setupView.isHidden = false

                    } else {

                        self.view.window?.close()

                    }


                }

                self.presentAsSheet(createPresentationController)

            }
        
        }
        
    }
    
    override func viewWillLayout() {
        super.viewWillLayout()
        
        pageDetailsView.collectionViewLayout?.invalidateLayout()
        
    }
    
}

extension PresentationViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageDetailsViewItem"), for: indexPath) as! PageDetailsViewItem
        
        item.pageTitle?.stringValue = "jell"
        
        guard let url = URL(string: "file:///Users/ethan.lin/Desktop/GitHub/sbplus_v3/build/assets/audio/slide01.mp3") else { return item }
        
        let player = AVPlayer(url: url)
        item.mediaPreview?.player = player
        
        let image = NSImage(named: "slide01")
        image!.backgroundColor = NSColor.red
        let imageViewObject = NSImageView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        imageViewObject.image = image
        imageViewObject.sizeToFit()
        
        let button = NSButton(title: "Hello", target: nil, action: nil);
        item.mediaPreview?.contentOverlayView?.addSubview(button)
        print(item.mediaPreview?.contentOverlayView)
        
        return item
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
}

extension PresentationViewController: NSCollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        
        if (collectionView.identifier?.rawValue == SegueIdentifiers.pageDetails) {
            
            return CGSize(width: pageDetailsView.bounds.width, height: PageDetailsViewItem().view.bounds.height)
            
        }
        
        return CGSize(width: 50, height: 50)
        
    }
    
}
