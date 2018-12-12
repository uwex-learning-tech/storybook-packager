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
    @IBOutlet weak var accentColorErrorLbl: NSTextField!
    
    var settings: PresentationSettings = PresentationSettings()
    var completionHandler: ((PresentationSettings) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        accentColorErrorLbl.isHidden = true
        accentColorSetup()
        
    }
    
    override func viewWillAppear() {

        let savedSettings = (NSDocumentController.shared.currentDocument as! Document).getXmlObj()
        
        splashImgType.selectItem(withTitle: savedSettings.splashImgFormat.uppercased())
        pageImgType.selectItem(withTitle: savedSettings.pageImgFormat.uppercased())
        accentColorTxtfld.stringValue = savedSettings.accent
        accentColorWell.color = Util.shared.fromHex(hex: (savedSettings.accent))
        
        if (savedSettings.analytics) {
            analyticsOn.state = .on
        }

        if (savedSettings.mathJax) {
            mathJaxOn.state = .on
        }
        
    }
    
    @IBAction func savePresenationSettings(_ sender: NSButton) {
        
        settings.splashImgType = splashImgType.titleOfSelectedItem!.lowercased()
        settings.pageImgType = pageImgType.titleOfSelectedItem!.lowercased()
        settings.analyticsOn = analyticsOn.state == .on ? true : false
        settings.mathJaxOn = mathJaxOn.state == .on ? true : false
        settings.accentColor = accentColorTxtfld.stringValue
        settings.OK = true
        settings.CANCEL = false
        
        completionHandler?(settings)
        
    }
    
    @IBAction func cancelPresenationSettings(_ sender: NSButton) {
        
        settings.OK = false
        settings.CANCEL = true
        completionHandler?(settings)
        
    }
    
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
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
        accentColorErrorLbl.stringValue = ""
        accentColorErrorLbl.isHidden = true
        settings.hasError = false
    }
    
    private func showAccentColorError() {
        accentColorTxtfld.layer?.borderWidth = 1
        accentColorTxtfld.layer?.borderColor = NSColor.systemRed.cgColor
        accentColorErrorLbl.stringValue = "Invalid hexadecimal!"
        accentColorErrorLbl.isHidden = false
        settings.hasError = true
    }
    
    // END FUNCTIONS FOR ACCENT COLOR
    
}



struct PresentationSettings {
    var splashImgType: String = "svg"
    var pageImgType: String = "svg"
    var analyticsOn: Bool = false
    var mathJaxOn: Bool = false
    var accentColor: String = "0c3b6b"
    var OK: Bool = false
    var hasError: Bool = false
    var CANCEL: Bool = false
}
