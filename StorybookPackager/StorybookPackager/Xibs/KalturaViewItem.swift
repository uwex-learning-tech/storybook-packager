//
//  PageDetailsViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/3/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit

class KalturaViewItem: NSCollectionViewItem {
    
    @IBOutlet weak var mediaPreview: AVPlayerView!
    @IBOutlet weak var pageTitle: NSTextField!
    @IBOutlet var notesTxtvw: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: mediaPreview.player?.currentItem)
        
    }
    
    @objc func playerDidEnd(_ sender: NSNotification) {
        mediaPreview.player?.seek(to: CMTime.zero)
    }
    
}
