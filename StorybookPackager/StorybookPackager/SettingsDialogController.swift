//
//  SettingsDialogController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/10/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class SettingsDialogController: NSViewController {

    @IBOutlet weak var splashImgType: NSPopUpButton!
    @IBOutlet weak var pageImgType: NSPopUpButton!
    @IBOutlet weak var analyticsOn: NSButton!
    @IBOutlet weak var mathJaxOn: NSButton!
    @IBOutlet weak var accentColorWell: NSColorWell!
    @IBOutlet weak var accentColorTxtfld: NSTextField!
    
    var presentationSettings: PresentationSettings?
    var completionHandler: ((PresentationSettings) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        presentationSettings = PresentationSettings()
        
    }
    
    override func viewWillAppear() {
        
        let settings = (NSDocumentController.shared.currentDocument as? Document)?.getXmlObj()
        
        splashImgType.stringValue = (settings?.splashImgFormat.uppercased())!
        pageImgType.stringValue = (settings?.pageImgFormat.uppercased())!
        accentColorTxtfld.stringValue = (settings?.accent)!
        
        if ((settings?.analytics)!) {
            analyticsOn.state = .on
        }
        
        if ((settings?.mathJax)!) {
            mathJaxOn.state = .on
        }
        
    }
    
    @IBAction func savePresenationSettings(_ sender: NSButton) {
        
        presentationSettings?.splashImgType = splashImgType.stringValue.lowercased()
        presentationSettings?.pageImgType = splashImgType.stringValue.lowercased()
        presentationSettings?.analyticsOn = analyticsOn.state == .on ? true : false
        presentationSettings?.mathJaxOn = mathJaxOn.state == .on ? true : false
        presentationSettings?.accentColor = accentColorTxtfld.stringValue
        
        self.completionHandler?(self.presentationSettings!)
        
    }
    
    @IBAction func cancelPresenationSettings(_ sender: NSButton) {
        
        self.completionHandler?(self.presentationSettings!)
        
    }
    
    // BEGIN FUNCTIONS FOR ACCENT COLOR
    
    private func accentColorSetup() {
        
        // set accent color text with color hex value from accent color well
        let accentColor = accentColorWell.color
        accentColorTxtfld.stringValue = Util.shared.getHexFrom(color: accentColor)
        
        // add observer for accent color well change
        accentColorWell.addObserver(self, forKeyPath: "color", options: .new, context: nil)
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if (keyPath! == "color") {
            accentColorTxtfld.stringValue = Util.shared.getHexFrom(color: accentColorWell.color)
            clearAccentColorError()
        }
        
    }
    
    @IBAction func updateColorWell(_ sender: NSTextField) {
        
        var hex = sender.stringValue
        
        if (hex.hasPrefix("#")) {
            
            var offset = 6
            
            if (hex.count == 4) {
                offset = 3
            }
            
            hex = String(hex.suffix(offset))
            
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
        accentColorTxtfld.layer?.borderWidth = 1
        accentColorTxtfld.layer?.borderColor = NSColor.darkGray.cgColor
        //accentColorTip.stringValue = ""
        //accentColorTip.isHidden = true
    }
    
    private func showAccentColorError() {
        accentColorTxtfld.layer?.borderWidth = 1
        accentColorTxtfld.layer?.borderColor = NSColor.systemRed.cgColor
        //accentColorTip.stringValue = "Invalid hexadecimal!"
        //accentColorTip.isHidden = false
    }
    
    // END FUNCTIONS FOR ACCENT COLOR
    
}



struct PresentationSettings {
    var splashImgType: String = "svg"
    var pageImgType: String = "svg"
    var analyticsOn: Bool = false
    var mathJaxOn: Bool = false
    var accentColor: String = "#0c3b6b"
}
