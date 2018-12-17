//
//  PageDetailsViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/3/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class ImageAudioViewItem: NSCollectionViewItem {
    

    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var imgSrcTxtfld: NSTextField!
    @IBOutlet weak var audioSrcTxtfld: NSTextField!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var imageWell: NSImageView!
    @IBOutlet var notesTxtvw: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        
    }
    
    
    @IBAction func browseImgSrc(_ sender: NSButton) {
        
        print("Img browse click")
        
    }
    
    @IBAction func browseAudioSrc(_ sender: NSButton) {
        
        print("Audio browse click")
        
    }
    
    
}
