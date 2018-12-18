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
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var entryIdTxtfld: NSTextField!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var videoPlayer: AVPlayerView!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet var notesTxtvw: NSTextView!
    
    private var previousEntryId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: videoPlayer.player?.currentItem)
        
    }
    
    override func viewWillAppear() {
        
        guard let url = URL(string: "https://cdnapisec.kaltura.com/p/1660872/sp/0/playManifest/entryId/\(entryIdTxtfld.stringValue)/format/applehttp/protocol/https/flavorParamId/487081/video.mp4") else { return }
        
        let avAsset = AVURLAsset(url: url, options: nil)
        let playerItem = AVPlayerItem(asset: avAsset)
        let player = AVPlayer(playerItem: playerItem)
        
        videoPlayer.player = player
        
        previousEntryId = entryIdTxtfld.stringValue
        
    }
    
    @IBAction func entryIdChange(_ sender: NSTextField) {
        
        if (sender.stringValue != previousEntryId) {
            
            guard let url = URL(string: "https://cdnapisec.kaltura.com/p/1660872/sp/0/playManifest/entryId/\(entryIdTxtfld.stringValue)/format/applehttp/protocol/https/flavorParamId/487081/video.mp4") else { return }
            
            let avAsset = AVURLAsset(url: url, options: nil)
            let playerItem = AVPlayerItem(asset: avAsset)
            
            videoPlayer.player?.replaceCurrentItem(with: playerItem)
            
            previousEntryId = entryIdTxtfld.stringValue
            (NSDocumentController.shared.currentDocument as? Document)!.updateChangeCount(.changeDone)
            
        }
        
        
    }
    
    @objc func playerDidEnd(_ sender: NSNotification) {
        videoPlayer.player?.seek(to: CMTime.zero)
    }
    
}
