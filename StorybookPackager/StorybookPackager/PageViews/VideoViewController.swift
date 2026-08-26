//
//  VideoViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/15/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit

class VideoViewController: NSViewController {
    
    @IBOutlet weak var reloadMsg: NSBox!
    @IBOutlet weak var videoPlayer: AVPlayerView!
    
    var videoId: String?
    var videoUrl: URL?

    /// Set by PageViewController before the video is loaded; nil when the slide has no captions.
    var captions: CaptionTrack?

    private var captionOverlay: CaptionOverlayView?
    private var captionObserver: Any?
    // Strong on purpose: the player this observer belongs to must still be here to remove it from,
    // even after AVPlayerView has been handed a different one.
    private var observedPlayer: AVPlayer?
    
    private let kPartnerId = UserDefaults.standard.string(forKey: Preferences.KALTURA_PARTNER_ID)!
    private let flavorId = UserDefaults.standard.string(forKey: Preferences.KALTURA_FLAVOR_ID)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        reloadMsg.isHidden = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: videoPlayer.player?.currentItem)
        
    }

    // The slide takes a dropped video itself (see VideoDropTargetView); the player is only asked to
    // stay out of the way of the drag on its way there.
    override func viewDidLayout() {
        super.viewDidLayout()
        videoPlayer.disableFileDrops()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()

        stopCaptions()

        if videoPlayer != nil {
            
            if videoPlayer.player != nil {
                videoPlayer.player?.pause()
                videoPlayer.player = nil
            }
            
        }
        
        reloadMsg.isHidden = true
        
    }
    
    // viewWillDisappear is the ordinary path, but a controller can be torn down without it — and an
    // AVPlayer released while a periodic observer is still attached is a hard error, not a leak.
    deinit {
        stopCaptions()
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

            // A streaming slide has no captions to show, but it can still be replacing a player
            // that had an observer on it.
            stopCaptions()
            
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
                
                // Captions first: assigning the player drops the previous one's last strong
                // reference, and a periodic observer has to be removed before that happens.
                startCaptions(on: player)

                videoPlayer.player = player
                
            } else {
                reloadMsg.isHidden = false
            }
            
        }
        
    }
    
    @objc func playerDidEnd(_ sender: NSNotification) {
        videoPlayer.player?.seek(to: CMTime.zero)
    }

    // Cues are found and drawn here rather than handed to the player as a track: the caption file
    // is a wrapper inside the document package, not a URL, and giving AVFoundation a real track
    // would mean composing an asset around a file that only exists once the document is saved.
    private func startCaptions(on player: AVPlayer) {

        stopCaptions()

        guard captions != nil else { return }

        if captionOverlay == nil {
            // Clear of the player's own transport controls, which fade in over the bottom edge.
            // AVPlayerView owns its subview tree and offers contentOverlayView for exactly this;
            // a foreign direct subview can end up under the video or behind the transport controls.
            captionOverlay = CaptionOverlayView.install(in: videoPlayer.contentOverlayView ?? videoPlayer,
                                                        bottomInset: 60)
        }

        observedPlayer = player

        // Four times a second: cue boundaries land on tenths at best, and a caption that changes a
        // quarter-second late reads as being in sync while costing almost nothing to poll.
        captionObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                                                        queue: .main) { [weak self] time in

            guard let self = self else { return }

            self.captionOverlay?.show(self.captions?.text(at: time.seconds))

        }

    }

    private func stopCaptions() {

        if let observer = captionObserver {
            observedPlayer?.removeTimeObserver(observer)
        }

        captionObserver = nil
        observedPlayer = nil
        captionOverlay?.show(nil)

    }
    
}
