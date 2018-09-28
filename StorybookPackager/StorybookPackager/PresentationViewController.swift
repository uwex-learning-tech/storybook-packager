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
    
    var presentation: PresentationMeta = PresentationMeta()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
    }
    
    override func viewDidAppear() {
        
        // temporarly commented out
        if ( presentation.location.isEmpty ) {

            if let createPresentationController = self.storyboard?.instantiateController(withIdentifier: SegueIdentifiers.newPresentation) as? NewPresentationDialogController {

                createPresentationController.completionHandler = { (result) -> () in

                    if ( result.completed ) {

                        self.presentation = result.presentationMeta
                        print(self.presentation as Any)
                        self.presentationSetupView.isHidden = false

                    } else {

                        self.view.window?.close()

                    }


                }

                self.presentAsSheet(createPresentationController)

            }
        
        }
        
    }
    
}

