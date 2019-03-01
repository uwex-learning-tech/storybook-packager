//
//  DownloadablesViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/13/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class DownloadablesViewController: NSViewController {

    @IBOutlet weak var pdfBtn: NSButton!
    @IBOutlet weak var mp3Btn: NSButton!
    @IBOutlet weak var mp4Btn: NSButton!
    @IBOutlet weak var zipBtn: NSButton!
    @IBOutlet weak var removePdfBtn: NSButton!
    @IBOutlet weak var removeMp3Btn: NSButton!
    @IBOutlet weak var removeMp4Btn: NSButton!
    @IBOutlet weak var removeZipBtn: NSButton!
    
    private var doc: Document?
    private let setColor: NSColor = NSColor.white
    private let unsetColor: NSColor = NSColor.darkGray
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height)
        pdfBtn.image = NSImage(named: "pdf_file")?.imageTint(withColor: unsetColor)
        mp3Btn.image = NSImage(named: "mp3_file")?.imageTint(withColor: unsetColor)
        mp4Btn.image = NSImage(named: "mp4_file")?.imageTint(withColor: unsetColor)
        zipBtn.image = NSImage(named: "zip_file")?.imageTint(withColor: unsetColor)
        removePdfBtn.isHidden = true
        removeMp3Btn.isHidden = true
        removeMp4Btn.isHidden = true
        removeZipBtn.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(self.fileDropped), name: Notification.Name("fileDropped"), object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        doc = NSDocumentController.shared.currentDocument as? Document
        let fileName:String = (doc?.fileURL?.deletingPathExtension().lastPathComponent)! + "."
        
        if (doc?.fileWrapperExistsInRoot(name: fileName + FileExtensions.PDF))! {
            pdfBtn.image = NSImage(named: "pdf_file")?.imageTint(withColor: setColor)
            removePdfBtn.isHidden = false
        }
        
        if (doc?.fileWrapperExistsInRoot(name: fileName + FileExtensions.MP3))! {
            mp3Btn.image = NSImage(named: "mp3_file")?.imageTint(withColor: setColor)
            removeMp3Btn.isHidden = false
        }
        
        if (doc?.fileWrapperExistsInRoot(name: fileName + FileExtensions.MP4))! {
            mp4Btn.image = NSImage(named: "mp4_file")?.imageTint(withColor: setColor)
            removeMp4Btn.isHidden = false
        }
        
        if (doc?.fileWrapperExistsInRoot(name: fileName + FileExtensions.ZIP))! {
            zipBtn.image = NSImage(named: "zip_file")?.imageTint(withColor: setColor)
            removeZipBtn.isHidden = false
        }
        
    }
    
    @IBAction func browseForFile(_ sender: Any) {
        
        guard let btn = sender as? NSButton else { return }
        
        switch btn.alternateTitle {
        case FileExtensions.PDF:
            openFileBrowser(sender: btn, type: FileExtensions.PDF)
        case FileExtensions.MP3:
            openFileBrowser(sender: btn, type: FileExtensions.MP3)
        case FileExtensions.MP4:
            openFileBrowser(sender: btn, type: FileExtensions.MP4)
        case FileExtensions.ZIP:
            openFileBrowser(sender: btn, type: FileExtensions.ZIP)
        default:
            return
        }
        
    }
    
    @IBAction func removeDownloadFile(_ sender: Any) {
        
        guard let btn = sender as? NSButton else { return }
        
        let fileName:String = (doc?.fileURL?.deletingPathExtension().lastPathComponent)! + "."
        
        switch btn.alternateTitle {
        case FileExtensions.PDF:
            pdfBtn.image = NSImage(named: "pdf_file")?.imageTint(withColor: unsetColor)
            doc?.removeDownloadFile(file: fileName + FileExtensions.PDF)
        case FileExtensions.MP3:
            mp3Btn.image = NSImage(named: "mp3_file")?.imageTint(withColor: unsetColor)
            doc?.removeDownloadFile(file: fileName + FileExtensions.MP3)
        case FileExtensions.MP4:
            mp4Btn.image = NSImage(named: "mp4_file")?.imageTint(withColor: unsetColor)
            doc?.removeDownloadFile(file: fileName + FileExtensions.MP4)
        case FileExtensions.ZIP:
            zipBtn.image = NSImage(named: "zip_file")?.imageTint(withColor: unsetColor)
            doc?.removeDownloadFile(file: fileName + FileExtensions.ZIP)
        default:
            return
        }
        
        btn.isHidden = true
        doc!.save(nil)
        
    }
    
    @objc func fileDropped(_ sender: NSNotification) {
        
        guard let userInfo = sender.userInfo else { return }
        guard let ext = userInfo["extension"] as? String else { return }
        
        switch ext {
        case FileExtensions.PDF:
            pdfBtn.image = NSImage(named: "pdf_file")?.imageTint(withColor: setColor)
            removePdfBtn.isHidden = false
        case FileExtensions.MP3:
            mp3Btn.image = NSImage(named: "mp3_file")?.imageTint(withColor: setColor)
            removeMp3Btn.isHidden = false
        case FileExtensions.MP4:
            mp4Btn.image = NSImage(named: "mp4_file")?.imageTint(withColor: setColor)
            removeMp4Btn.isHidden = false
        case FileExtensions.ZIP:
            zipBtn.image = NSImage(named: "zip_file")?.imageTint(withColor: setColor)
            removeZipBtn.isHidden = false
        default: return
            
        }
        
    }
    
    private func openFileBrowser(sender:NSButton, type: String) {
        
        let fileBrowsePanel = NSOpenPanel()
        fileBrowsePanel.allowsMultipleSelection = false
        fileBrowsePanel.canChooseDirectories = false
        fileBrowsePanel.allowedFileTypes = [type]
        
        fileBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if (result == NSApplication.ModalResponse.OK) {
                
                let name = self.doc?.fileURL?.deletingPathExtension().lastPathComponent
                let fileName = "\(name!).\(type)"
                
                if self.doc!.fileWrapperExistsInRoot(name: fileName) {
                    self.doc!.removeDownloadFile(file: fileName)
                    self.doc!.addDownloadFile(name: fileName, url: fileBrowsePanel.url!)
                } else {
                    self.doc!.addDownloadFile(name: fileName, url: fileBrowsePanel.url!)
                    NotificationCenter.default.post(name: Notification.Name("fileDropped"), object: nil, userInfo: ["extension":type])
                }
                
                self.doc!.save(nil)
                
            }
            
        } )
        
    }
    
}

extension NSImage {
    func imageTint(withColor: NSColor) -> NSImage {
        
        if self.isTemplate == false {
            return self
        }
        
        let image = self.copy() as! NSImage
        image.lockFocus()
        
        withColor.set()
        __NSRectFillUsingOperation(NSMakeRect(0,0,image.size.width, image.size.height), NSCompositingOperation.sourceAtop)
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
        
    }
}
