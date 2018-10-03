//
//  PresentationViewController.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class PresentationViewController: NSViewController {
    
    @IBOutlet weak var presentationSetupView: NSView!
    @IBOutlet weak var pageDetailsView: NSCollectionView!
    
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
                        
                        self.presentationSetupView.isHidden = false

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
        
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "PageDetailsViewItem"), for: indexPath)
        
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
