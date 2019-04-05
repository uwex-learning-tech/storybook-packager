//
//  VideoViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/15/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit

class VideoViewController: NSViewController {
    
    @IBOutlet weak var reloadMsg: NSBox!
    @IBOutlet weak var videoPlayer: AVPlayerView!
    
    var videoId: String?
    var videoUrl: URL?
    
    private let kPartnerId = UserDefaults.standard.string(forKey: Preferences.KALTURA_PARTNER_ID)!
    private let flavorId = UserDefaults.standard.string(forKey: Preferences.KALTURA_FLAVOR_ID)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        reloadMsg.isHidden = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: videoPlayer.player?.currentItem)
        
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        if videoPlayer != nil {
            
            if videoPlayer.player != nil {
                videoPlayer.player?.pause()
                videoPlayer.player = nil
            }
            
        }
        
        reloadMsg.isHidden = true
        
    }
    
    @IBAction func saveAndReload(_ sender: NSButton) {
        
        NSDocumentController.shared.currentDocument?.save(nil)
        setVideo()
        reloadMsg.isHidden = true
        
    }
    
    func setKalturaVideo() {
        
        if videoId != nil {
            
            guard let url = URL(string: "https://cdnapisec.kaltura.com/p/\(kPartnerId)/sp/0/playManifest/entryId/\(videoId!)/format/applehttp/protocol/https/flavorParamId/\(flavorId)/video.mp4") else { return }
            
            let avAsset: AVAsset = AVURLAsset(url: url, options: nil)
            let playerItem = AVPlayerItem(asset: avAsset)
            let player = AVPlayer(playerItem: playerItem)
            
            videoPlayer.player = player
            
        }
        
    }
    
    func setVideo() {
        
        if videoUrl != nil {
            
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: videoUrl!.path) {
                
                let avAsset: AVAsset = AVAsset(url: videoUrl!)
                let playerItem = AVPlayerItem(asset: avAsset)
                let player = AVPlayer(playerItem: playerItem)
                
                videoPlayer.player = player
                
            } else {
                reloadMsg.isHidden = false
            }
            
        }
        
    }
    
    @objc func playerDidEnd(_ sender: NSNotification) {
        videoPlayer.player?.seek(to: CMTime.zero)
    }
    
}
