//
//  ImageViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/13/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import WebKit

class ImageViewController: NSViewController {

    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var svgImageView: WKWebView!
    
    var file: FileWrapper?
    var fileType: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        imageView.alphaValue = 0
        svgImageView.alphaValue = 0
        
        svgImageView.setValue(false, forKey: "drawsBackground")
        
        let imgFileUrl = Bundle.main.url(forResource: ObjIdentifiers.PAGE_IMAGE_PLACEHOLDER, withExtension: FileExtensions.PNG)?.absoluteURL
        let data = NSData(contentsOf: imgFileUrl!)?.base64EncodedString(options: NSData.Base64EncodingOptions.endLineWithLineFeed)
        
        svgImageView.loadHTMLString(Util.shared.formatImgHtml(base64: data!), baseURL: URL(string: "http://localhost"))
        
    }
    
    func setImage() {
        
        if file != nil {
            
            if fileType == FileExtensions.SVG {
                
                let svg = String(data: file!.regularFileContents!, encoding: String.Encoding.utf8)
                
                svgImageView.isHidden = false
                svgImageView.loadHTMLString(Util.shared.formatSvg(str: svg!), baseURL: URL(string: "http://localhost"))
                
                imageView.isHidden = true
                
            } else {
                
                imageView.isHidden = false
                imageView.image = NSImage(data: file!.regularFileContents!)
                
                svgImageView.isHidden = true
                
            }
            
        }
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 0.5
            
            if fileType == FileExtensions.SVG {
                svgImageView.animator().alphaValue = 1
                
            } else {
                imageView.animator().alphaValue = 1
            }
            
        }, completionHandler: nil)
        
    }
    
}
