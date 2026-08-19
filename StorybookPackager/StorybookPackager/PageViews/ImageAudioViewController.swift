//
//  ImageAudioViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/15/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import WebKit
import AVFoundation

class ImageAudioViewController: NSViewController, AVAudioPlayerDelegate, WKNavigationDelegate {

    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var svgImageView: WKWebView!
    @IBOutlet weak var audioPlayerBox: NSBox!
    @IBOutlet weak var audioPlayBtn: NSButton!
    @IBOutlet weak var audioSlider: NSSlider!
    @IBOutlet weak var currentTime: NSTextField!
    @IBOutlet weak var duration: NSTextField!
    
    var file: FileWrapper?
    var audio: FileWrapper?
    var fileType: String?
    var onImageRendered: ((NSImage) -> Void)?
    
    /// Set by PageViewController before the slide is loaded; nil when the slide has no captions.
    var captions: CaptionTrack?

    private var captionOverlay: CaptionOverlayView?

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioBoxTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.wantsLayer = true
        
        imageView.alphaValue = 0
        
        svgImageView.alphaValue = 0
        svgImageView.navigationDelegate = self
        svgImageView.setValue(false, forKey: "drawsBackground")
        
        audioPlayBtn.isEnabled = false
        audioSlider.isEnabled = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.mouseOver), name: Notification.Name("mouseOver"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.mouseOut), name: Notification.Name("mouseOut"), object: nil)
        
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        audioPlayerBox.alphaValue = 1
        audioBoxTimer?.invalidate()
        timer?.invalidate()
        audioPlayer?.stop()
        audioPlayer = nil
        audioPlayBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
        audioPlayBtn.isEnabled = false
        audioSlider.isEnabled = false
        currentTime.stringValue = "00:00"
        duration.stringValue = "00:00"
        audioSlider.doubleValue = 0.0
        captionOverlay?.show(nil)
        
    }
    
    @IBAction func playPauseAudio(_ sender: NSButton) {
        
        if (audioPlayer!.isPlaying) {
            
            audioPlayer?.pause()
            sender.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
            updateView()
            timer?.invalidate()
            
            audioPlayerBox.alphaValue = 1
            
            if audioBoxTimer != nil {
                audioBoxTimer!.invalidate()
            }
            
        } else {
            
            audioPlayer?.play()
            sender.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause")
            startTimer()
            
        }
        
    }
    
    @IBAction func onAudioScrub(_ sender: NSSlider) {
        audioPlayer!.currentTime = sender.doubleValue
        currentTime.stringValue = Util.shared.timeAsString(timeInterval: sender.doubleValue)
        showCaption(at: sender.doubleValue)
    }
    
    @objc func mouseOver(_ sender: Notification) {
        
        guard (sender.object as? NSWindow) == self.view.window else { return }
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 0.25
            
            audioPlayerBox.animator().alphaValue = 1
            
            if audioBoxTimer != nil {
                audioBoxTimer!.invalidate()
            }
            
        })
        
    }
    
    @objc func mouseOut(_ sender: Notification) {
        
        guard (sender.object as? NSWindow) == self.view.window else { return }
        
        if audioPlayer != nil && audioPlayer!.isPlaying {
            setFadeAudioBoxOut()
        }
        
    }
    
    func setImage() {
        
        if file != nil {
            
            if fileType == FileExtensions.SVG {
                
                let svgString = String(data: file!.regularFileContents!, encoding: .utf8)
                svgImageView.loadHTMLString(Util.shared.formatSvg(str: svgString!), baseURL: URL(string: "http://localhost"))
                
            } else {
                
                svgImageView.isHidden = true
                imageView.image = NSImage(data: file!.regularFileContents!)
                Util.shared.animateIn(image: imageView)
                
            }
            
        }
        
        // set audio
        setAudio()
    }
    
    private func setAudio() {
        
        // set audio
        if audio != nil {
            
            do {
                
                audioPlayer = try AVAudioPlayer(data: audio!.regularFileContents!)
                audioPlayer!.delegate = self
                
                audioSlider.minValue = 0.0
                audioSlider.maxValue = audioPlayer!.duration
                
                duration.stringValue = Util.shared.timeAsString(timeInterval: audioPlayer!.duration)
                currentTime.stringValue = Util.shared.timeAsString(timeInterval: audioPlayer!.currentTime)
                
                audioPlayBtn.isEnabled = true
                audioSlider.isEnabled = true
                
            } catch let error as NSError {
                
                print(error.localizedDescription)
                
            }
            
        }
        
    }
    
    private func startTimer() {
        // A quarter-second tick: at half a second a caption visibly trails the narration,
        // which is the one thing this display exists to let someone check.
        timer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(self.updateViewWithTimer), userInfo: nil, repeats: true)
    }
    
    @objc func updateViewWithTimer(timer: Timer) {
        updateView()
    }
    
    private func updateView() {
        
        currentTime.stringValue = Util.shared.timeAsString(timeInterval: audioPlayer!.currentTime)
        audioSlider.doubleValue = audioPlayer!.currentTime

        showCaption(at: audioPlayer!.currentTime)
        
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        audioPlayerBox.alphaValue = 1
        audioPlayBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
        timer?.invalidate()
        updateView()
        
    }
    
    private func setFadeAudioBoxOut() {
        
        audioBoxTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.fadeAudioBoxOut), userInfo: nil, repeats: false)
        
    }
    
    @objc private func fadeAudioBoxOut() {
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 1
            
            audioPlayerBox.animator().alphaValue = 0
            
        }, completionHandler: {
            
            self.audioBoxTimer?.invalidate()
            
        })
        
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        webView.takeSnapshot(with: .none, completionHandler: {(img, error) in
            
            if img != nil {
                webView.isHidden = true
                self.imageView.image = img!
                Util.shared.animateIn(image: self.imageView)
                self.onImageRendered?(img!)
                self.onImageRendered = nil
            }
            
        })
        
    }
    

    // The cues are drawn here rather than played through the audio player, which has no notion of a
    // caption track at all. The bar hangs above the floating transport controls so it reads as
    // sitting under the slide image, where a viewer of the finished presentation would see it.
    private func showCaption(at time: TimeInterval) {

        guard let captions = captions else { return }

        if captionOverlay == nil {
            captionOverlay = CaptionOverlayView.install(in: view, above: audioPlayerBox)
        }

        captionOverlay?.show(captions.text(at: time))

    }

}
