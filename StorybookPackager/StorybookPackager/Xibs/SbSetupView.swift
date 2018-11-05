//
//  SbSetupView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/9/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class SbSetupView: NSView {

    @IBOutlet var contentView: NSView!
    @IBOutlet weak var accentColorTxtFld: NSTextField!
    @IBOutlet weak var accentColorWell: NSColorWell!
    @IBOutlet weak var accentColorTip: NSTextField!
    
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        // Drawing code here.
//    }
    
    @IBAction func updateColorWell(_ sender: NSTextField) {
        
        var hex = accentColorTxtFld.stringValue
        
        if (hex.count == 3) {
            hex = "\(hex)\(hex)"
        }
        
        if (Util.shared.isHex(value: hex)) {
            accentColorWell.color = Util.shared.fromHex(hex: hex)
            accentColorTip.stringValue = ""
            accentColorTip.isHidden = true
        } else {
            accentColorTip.stringValue = "Invalid hexadecimal!"
            accentColorTip.isHidden = false
        }
        
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        commonInit()
    }
    
    private func commonInit() {
        
        Bundle.main.loadNibNamed(ViewIdentifiers.setupView, owner: self, topLevelObjects: nil)

        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.width]
        
        // set accent color text with color hex value from accent color well
        let accentColor = accentColorWell.color
        accentColorTxtFld.stringValue = Util.shared.getHexFrom(color: accentColor)
        
        // add observer for accent color well change
        accentColorWell.addObserver(self, forKeyPath: "color", options: .new, context: nil)
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if (keyPath! == "color") {
            accentColorTxtFld.stringValue = Util.shared.getHexFrom(color: accentColorWell.color)
        }
        
    }
    
}
