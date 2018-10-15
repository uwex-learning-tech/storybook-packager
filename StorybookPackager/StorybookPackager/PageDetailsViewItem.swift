//
//  PageDetailsViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/3/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import AVKit
import AVFoundation

class PageDetailsViewItem: NSCollectionViewItem {
    
    @IBOutlet weak var mediaPreview: AVPlayerView!
    @IBOutlet weak var pageTitle: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
    }
    
}
