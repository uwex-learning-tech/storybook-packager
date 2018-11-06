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
    
    var awoke: Bool = false
    
    
    
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
        
    }
    
    override func awakeFromNib() {
        
        if (!awoke) {
            awoke = true
            return
        }
        
        // set accent color text with color hex value from accent color well
        
        let accentColor = accentColorWell.color
        accentColorTxtFld.stringValue = Util.shared.getHexFrom(color: accentColor)
        
        // add observer for accent color well change
        accentColorWell.addObserver(self, forKeyPath: "color", options: .new, context: nil)
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if (keyPath! == "color") {
            accentColorTxtFld.stringValue = Util.shared.getHexFrom(color: accentColorWell.color)
            clearAccentColorError()
        }
        
    }
    
    @IBAction func updateColorWell(_ sender: NSTextField) {
        
        guard case let hex = sender.stringValue,
            hex.count == 0 || hex.count == 3 || hex.count == 6 else {
                showAccentColorError()
                return
            }
        
        if (hex.count == 0) {
            sender.stringValue = Util.shared.getHexFrom(color: accentColorWell.color)
            return
        }
        
        if (Util.shared.isHex(value: hex)) {
            
            if (hex.count == 3) {
                accentColorWell.color = Util.shared.fromHex(hex: hex + hex)
            } else {
                accentColorWell.color = Util.shared.fromHex(hex: hex)
            }
            
            clearAccentColorError()
            
        } else {
            showAccentColorError()
        }
        
    }
    
    private func clearAccentColorError() {
        accentColorTxtFld.layer?.borderWidth = 1
        accentColorTxtFld.layer?.borderColor = NSColor.darkGray.cgColor
        accentColorTip.stringValue = ""
        accentColorTip.isHidden = true
    }
    
    private func showAccentColorError() {
        accentColorTxtFld.layer?.borderWidth = 1
        accentColorTxtFld.layer?.borderColor = NSColor.systemRed.cgColor
        accentColorTip.stringValue = "Invalid hexadecimal!"
        accentColorTip.isHidden = false
    }
    
}
