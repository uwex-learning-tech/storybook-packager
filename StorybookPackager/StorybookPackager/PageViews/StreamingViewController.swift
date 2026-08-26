//
//  StreamingViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/15/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa
import WebKit

class StreamingViewController: NSViewController {
    
    @IBOutlet weak var webPlayer: WKWebView!
    
    var youtubeId: String?
    var vimeoId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webPlayer.setValue(false, forKey: "drawsBackground")
    }
    
    func setVideo() {
        
        if youtubeId != nil {
            
            webPlayer.loadHTMLString(Util.shared.formatIframe(str: youtubeId!, type: PageTypes.YOUTUBE), baseURL: URL(string: "http://localhost"))
            
        }
        
        if vimeoId != nil {
            
            webPlayer.loadHTMLString(Util.shared.formatIframe(str: vimeoId!, type: PageTypes.VIMEO), baseURL: URL(string: "http://localhost"))
            
        }
        
    }
    
}
