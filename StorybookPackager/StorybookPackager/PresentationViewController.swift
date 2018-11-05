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
    
    @IBOutlet weak var presentationSetupScrollView: NSScrollView!
    @IBOutlet weak var pageDetailsView: NSCollectionView!
    @IBOutlet weak var pageCollectionView: NSCollectionView!
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
                        
                        self.pageCollectionView.reloadData()
                        self.setupView.isHidden = false

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
        
        pageCollectionView.collectionViewLayout?.invalidateLayout()
        pageDetailsView.collectionViewLayout?.invalidateLayout()
        
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
            
            print(item.mediaPreview.contentOverlayView as Any)
            
            return item
            
        }
        
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
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        
        guard let item = collectionView.item(at: indexPaths.first!) as? PageViewItem else {
            return
        }
        
        item.container.layer?.borderColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        
    }
    
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        
        guard let item = collectionView.item(at: indexPaths.first!) as? PageViewItem else {
            return
        }
        
        item.container.layer?.borderColor = CGColor(gray: 1, alpha: 0.25)
        
    }
    
}
