//
//  BundleViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/18/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class BundleViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.mouseOver), name: Notification.Name("mouseOver"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.mouseOut), name: Notification.Name("mouseOut"), object: nil)
        
    }
    
    @objc func mouseOver(_ sender: Notification) {
        
        guard (sender.object as? NSWindow) == self.view.window else { return }
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 1
            
//            audioPlayerBox.animator().alphaValue = 1
//
//            if audioBoxTimer != nil {
//                audioBoxTimer!.invalidate()
//            }
            
        })
        
    }
    
    @objc func mouseOut(_ sender: Notification) {
        
        guard (sender.object as? NSWindow) == self.view.window else { return }
        
//        if audioPlayer != nil && audioPlayer!.isPlaying {
//            setFadeAudioBoxOut()
//        }
        
    }
    
}
