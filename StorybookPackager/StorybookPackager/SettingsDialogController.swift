//
//  SettingsDialogController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/10/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class SettingsDialogController: NSViewController {

    @IBOutlet weak var splashImgType: NSPopUpButton!
    @IBOutlet weak var pageImgType: NSPopUpButton!
    @IBOutlet weak var analyticsOn: NSButton!
    @IBOutlet weak var mathJaxOn: NSButton!
    @IBOutlet weak var accentColorWell: NSColorWell!
    @IBOutlet weak var accentColorTxtfld: NSTextField!
    @IBOutlet weak var accentColorErrorLbl: NSTextField!
    
    private var xmlObj: StorybookXml?
    
    var result: Result = Result()
    var completionHandler: ((Result) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        accentColorErrorLbl.isHidden = true
        accentColorSetup()
        
    }
    
    override func viewWillAppear() {

        xmlObj = (NSDocumentController.shared.currentDocument as! Document).getXmlObj()
        
        splashImgType.selectItem(withTitle: xmlObj!.splashImgFormat.uppercased())
        pageImgType.selectItem(withTitle: xmlObj!.pageImgFormat.uppercased())
        accentColorTxtfld.stringValue = xmlObj!.accent
        accentColorWell.color = Util.shared.fromHex(hex: (xmlObj!.accent))
        
        if (xmlObj!.analytics) {
            analyticsOn.state = .on
        }

        if (xmlObj!.mathJax) {
            mathJaxOn.state = .on
        }
        
    }
    
    @IBAction func savePresenationSettings(_ sender: NSButton) {
        
        self.view.window?.makeFirstResponder(nil)
        
        var hasChange: Bool = false
        
        if (xmlObj?.splashImgFormat != splashImgType.titleOfSelectedItem!.lowercased()) {
            xmlObj?.splashImgFormat = splashImgType.titleOfSelectedItem!.lowercased()
            hasChange = true
        }
        
        if (xmlObj?.pageImgFormat != pageImgType.titleOfSelectedItem!.lowercased()) {
            xmlObj?.pageImgFormat = pageImgType.titleOfSelectedItem!.lowercased()
            hasChange = true
        }
        
        if (xmlObj?.analytics != (analyticsOn.state == .on ? true : false)) {
            xmlObj?.analytics = analyticsOn.state == .on ? true : false
            hasChange = true
        }
        
        if (xmlObj?.mathJax != (mathJaxOn.state == .on ? true : false)) {
            xmlObj?.mathJax = mathJaxOn.state == .on ? true : false
            hasChange = true
        }
        
        if (xmlObj?.accent != accentColorTxtfld.stringValue) {
            
            if (!result.hasError) {
                xmlObj?.accent = accentColorTxtfld.stringValue
                hasChange = true
            }
            
        }
        
        result.OK = true
        result.CANCEL = false
        
        if (hasChange && !result.hasError) {
            (NSDocumentController.shared.currentDocument as! Document).updateChangeCount(NSDocument.ChangeType.changeDone)
        }
        
        completionHandler?(result)
        
    }
    
    @IBAction func cancelPresenationSettings(_ sender: NSButton) {
        
        result.OK = false
        result.CANCEL = true
        completionHandler?(result)
        
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
        result.hasError = false
    }
    
    private func showAccentColorError() {
        accentColorTxtfld.layer?.borderWidth = 1
        accentColorTxtfld.layer?.borderColor = NSColor.systemRed.cgColor
        accentColorErrorLbl.stringValue = "Invalid hexadecimal!"
        accentColorErrorLbl.isHidden = false
        result.hasError = true
    }
    
    // END FUNCTIONS FOR ACCENT COLOR
    
}

struct Result {
    var OK: Bool = false
    var hasError: Bool = false
    var CANCEL: Bool = false
}
