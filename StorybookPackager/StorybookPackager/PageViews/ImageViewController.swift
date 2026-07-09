//
//  ImageViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/13/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import WebKit

class ImageViewController: NSViewController, WKNavigationDelegate {

    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var svgImageView: WKWebView!
    
    var file: FileWrapper?
    var fileType: String?
    var onImageRendered: ((NSImage) -> Void)?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        imageView.alphaValue = 0
        svgImageView.alphaValue = 0
        svgImageView.navigationDelegate = self
        svgImageView.setValue(false, forKey: "drawsBackground")
        
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
    
}
