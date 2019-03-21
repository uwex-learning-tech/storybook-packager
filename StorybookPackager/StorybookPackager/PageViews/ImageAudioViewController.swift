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

class ImageAudioViewController: NSViewController, AVAudioPlayerDelegate {

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
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioBoxTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        self.view.wantsLayer = true
        
        imageView.alphaValue = 0
        svgImageView.alphaValue = 0
        
        audioPlayBtn.isEnabled = false
        audioSlider.isEnabled = false
        
        let imgFileUrl = Bundle.main.url(forResource: ObjIdentifiers.PAGE_IMAGE_PLACEHOLDER, withExtension: FileExtensions.PNG)?.absoluteURL
        let data = NSData(contentsOf: imgFileUrl!)?.base64EncodedString(options: NSData.Base64EncodingOptions.endLineWithLineFeed)
        
        svgImageView.loadHTMLString(Util.shared.formatImgHtml(base64: data!), baseURL: URL(string: "http://localhost"))
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.mouseOver), name: Notification.Name("mouseOver"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.mouseOut), name: Notification.Name("mouseOut"), object: nil)
        
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        svgImageView.loadHTMLString("", baseURL: URL(string: "http://localhost"))
        audioPlayerBox.alphaValue = 1
        audioBoxTimer?.invalidate()
        timer?.invalidate()
        audioPlayer?.stop()
        audioPlayer = nil
        audioPlayBtn.image = NSImage(named: "play_icn")
        audioPlayBtn.isEnabled = false
        audioSlider.isEnabled = false
        currentTime.stringValue = "00:00"
        duration.stringValue = "00:00"
        audioSlider.doubleValue = 0.0
        
    }
    
    @IBAction func playPauseAudio(_ sender: NSButton) {
        
        if (audioPlayer!.isPlaying) {
            
            audioPlayer?.pause()
            sender.image = NSImage(named: "play_icn")
            updateView()
            timer?.invalidate()
            
            audioPlayerBox.alphaValue = 1
            
            if audioBoxTimer != nil {
                audioBoxTimer!.invalidate()
            }
            
        } else {
            
            audioPlayer?.play()
            sender.image = NSImage(named: "pause_icn")
            startTimer()
            
        }
        
    }
    
    @IBAction func onAudioScrub(_ sender: NSSlider) {
        audioPlayer!.currentTime = sender.doubleValue
        currentTime.stringValue = Util.shared.timeAsString(timeInterval: sender.doubleValue)
    }
    
    @objc func mouseOver(_ sender: Notification) {

        guard (sender.object as? NSWindow) == self.view.window else { return }
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 1
            
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
                
                let svg = String(data: file!.regularFileContents!, encoding: String.Encoding.utf8)
                svgImageView.loadHTMLString(Util.shared.formatSvg(str: svg!), baseURL: URL(string: "http://localhost"))
                
            } else {
                
                imageView.image = NSImage(data: file!.regularFileContents!)
                
            }
            
        }
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 1
            
            if fileType == FileExtensions.SVG {
                svgImageView.animator().alphaValue = 1
                
            } else {
                imageView.animator().alphaValue = 1
            }
            
        }, completionHandler: {
            
            if self.fileType == FileExtensions.SVG {
                
                self.imageView.isHidden = true
                self.svgImageView.animator().isHidden = false
                
            } else {
                
                self.svgImageView.isHidden = true
                self.imageView.animator().isHidden = false
                
            }
            
        })
        
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
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.updateViewWithTimer), userInfo: nil, repeats: true)
    }
    
    @objc func updateViewWithTimer(timer: Timer) {
        updateView()
    }
    
    private func updateView() {
        
        currentTime.stringValue = Util.shared.timeAsString(timeInterval: audioPlayer!.currentTime)
        audioSlider.doubleValue = audioPlayer!.currentTime
        
    }
    
    private func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        audioPlayBtn.image = NSImage(named: "play_icn")
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
    
}
