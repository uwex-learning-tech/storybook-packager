//
//  SbSetupView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/9/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class SbSetupView: NSView {

    // the view itself
    @IBOutlet var contentView: NSView!
    
    // presentation title and subtitle
    @IBOutlet weak var titleTxtFld: NSTextField!
    @IBOutlet weak var subtitleTxtFld: NSTextField!
    
    // presentation estimated length or duration
    @IBOutlet weak var lengthTxtFld: NSTextField!
    
    // presentation author
    @IBOutlet weak var authorCmbBx: NSComboBox!
    @IBOutlet weak var profileTxtFld: NSTextField!
    
    // presentation general info
    @IBOutlet weak var generalInfoTxtFld: NSTextField!
    
    // presentation analytics and mathjax
    @IBOutlet weak var analyticsOnCb: NSButton!
    @IBOutlet weak var mathjaxOnCb: NSButton!
    
    // presentation splash and page image type
    @IBOutlet weak var splashImgTypePBtn: NSPopUpButton!
    @IBOutlet weak var pageImgTypePBtn: NSPopUpButton!
    
    // presenation accent color
    @IBOutlet weak var accentColorTxtFld: NSTextField!
    @IBOutlet weak var accentColorWell: NSColorWell!
    @IBOutlet weak var accentColorTip: NSTextField!
    
    // flag awakefromnib
    var awoke: Bool = false
    
    // BEGIN INIT FUNCTIONS
    
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
    
    // END INIT FUNCTIONS
    
    // when nib loaded
    override func awakeFromNib() {
        
        if (!awoke) {
            awoke = true
            return
        }
        
        // perform initial setup for accent color input fields
        accentColorSetup()
        
    }
    
    // BEGIN FUNCTIONS FOR ACCENT COLOR
    
    private func accentColorSetup() {
        
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
    
    // END FUNCTIONS FOR ACCENT COLOR
    
}
