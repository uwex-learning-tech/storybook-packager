//
//  ViewController.swift
//  XmlMacTest
//
//  Created by Ethan Lin on 7/6/18.
//  Copyright © 2018 University of Wisconsin System Office of Academic and Student Affairs. All rights reserved.
//

import Cocoa
import SbPlusXmlManager

class ViewController: NSViewController {
    
    let xmlMngr = SbXmlManager()
    
    @IBOutlet var output: NSTextView!
    @IBAction func selectFileBtn(_ sender: NSButton) {
        
        let singleFileOpenPanel = NSOpenPanel()

        singleFileOpenPanel.allowsMultipleSelection = false
        singleFileOpenPanel.canChooseDirectories = false
        singleFileOpenPanel.canChooseFiles = true
        singleFileOpenPanel.allowedFileTypes = ["xml"]
        
        singleFileOpenPanel.beginSheetModal(for: self.view.window!, completionHandler: { result in
            if result == NSApplication.ModalResponse.OK {
                
                let url = singleFileOpenPanel.url
                
                self.readFile( fileUrl: url! )
                
            }
            
        } )
        
    }
    
    @IBAction func saveToFileBtn(_ sender: NSButton) {

        if ( !output.string.isEmpty ) {
            
            let saveFileOpenPanel = NSSavePanel()
            saveFileOpenPanel.allowedFileTypes = ["xml"]
            saveFileOpenPanel.isExtensionHidden = false
            saveFileOpenPanel.canSelectHiddenExtension = true
            
            saveFileOpenPanel.beginSheetModal(for: self.view.window!, completionHandler: { result in
                
                if result == NSApplication.ModalResponse.OK {
                    
                    guard let saveUrl = saveFileOpenPanel.url else { return }
                    self.saveFile( path: saveUrl, content: self.output.string )
                    
                }
                
            } )
            
        } else {
            
            let alert = NSAlert()
            
            alert.messageText = "Empty output!"
            alert.informativeText = "No need to save."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            
            alert.beginSheetModal(for: self.view.window!, completionHandler: nil )
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    private func readFile( fileUrl: URL ) {
        
        do {
            
            output.string = try xmlMngr.read( path: fileUrl.absoluteString )
            
        } catch let error as NSError {
            
            output.string = error.localizedFailureReason!
            
        }
        
    }
    
    private func saveFile( path: URL, content: String ) {
        
        do {
            
            try xmlMngr.write( path: path, content: content )
            
        } catch let error as NSError {
            
            output.string = error.localizedFailureReason!
            
        }
        
        
        
    }
    
}

