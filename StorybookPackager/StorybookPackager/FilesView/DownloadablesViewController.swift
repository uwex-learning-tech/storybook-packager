//
//  DownloadablesViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/13/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class DownloadablesViewController: NSViewController {

    @IBOutlet weak var transcriptBtn: NSButton!
    @IBOutlet weak var mp3Btn: NSButton!
    @IBOutlet weak var mp4Btn: NSButton!
    @IBOutlet weak var zipBtn: NSButton!
    @IBOutlet weak var removeTranscriptBtn: NSButton!
    @IBOutlet weak var removeMp3Btn: NSButton!
    @IBOutlet weak var removeMp4Btn: NSButton!
    @IBOutlet weak var removeZipBtn: NSButton!
    
    private var doc: Document?
    private let setColor: NSColor = NSColor.white
    private let unsetColor: NSColor = NSColor.darkGray
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height)
        showTranscript(nil)
        mp3Btn.image = NSImage(named: "mp3_file")?.imageTint(withColor: unsetColor)
        mp4Btn.image = NSImage(named: "mp4_file")?.imageTint(withColor: unsetColor)
        zipBtn.image = NSImage(named: "zip_file")?.imageTint(withColor: unsetColor)
        removeMp3Btn.isHidden = true
        removeMp4Btn.isHidden = true
        removeZipBtn.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(self.fileDropped), name: Notification.Name("fileDropped"), object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        doc = NSDocumentController.shared.currentDocument as? Document
        let fileName:String = (doc?.fileURL?.deletingPathExtension().lastPathComponent)! + "."
        
        showTranscript(transcriptExtension())
        
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
        case Downloadable.TRANSCRIPT:
            openTranscriptBrowser()
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
        
        let docName: String = (doc?.fileURL?.deletingPathExtension().lastPathComponent)!
        let fileName: String = docName + "."
        
        switch btn.alternateTitle {
        case Downloadable.TRANSCRIPT:

            // Whichever form the transcript is in — the slot holds one at a time. Named through
            // Downloadable so a presentation called "index" can't have its player swept as if it
            // were the transcript.
            for name in Downloadable.transcriptFileNames(documentName: docName) {
                doc?.removeRootDirFile(file: name)
            }

            showTranscript(nil)

        case FileExtensions.MP3:
            mp3Btn.image = NSImage(named: "mp3_file")?.imageTint(withColor: unsetColor)
            doc?.removeRootDirFile(file: fileName + FileExtensions.MP3)
        case FileExtensions.MP4:
            mp4Btn.image = NSImage(named: "mp4_file")?.imageTint(withColor: unsetColor)
            doc?.removeRootDirFile(file: fileName + FileExtensions.MP4)
        case FileExtensions.ZIP:
            zipBtn.image = NSImage(named: "zip_file")?.imageTint(withColor: unsetColor)
            doc?.removeRootDirFile(file: fileName + FileExtensions.ZIP)
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
        case _ where Downloadable.isTranscript(ext):
            showTranscript(ext)
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
    
    /// Which form of transcript this presentation holds, if any.
    private func transcriptExtension() -> String? {

        guard let doc = doc, let name = doc.fileURL?.deletingPathExtension().lastPathComponent else { return nil }

        return Downloadable.transcriptExtension(inRootNames: doc.rootFileNames(), documentName: name)

    }

    /// One button for one slot, showing what is in it: the familiar PDF mark for a PDF, a page mark
    /// for a web transcript, and a plain document outline when there is none — an empty slot must
    /// not look like it is already holding a PDF.
    private func showTranscript(_ ext: String?) {

        switch ext {

        case FileExtensions.PDF:
            transcriptBtn.image = NSImage(named: "pdf_file")?.imageTint(withColor: setColor)
            transcriptBtn.toolTip = "Transcript: a PDF. Choose again to replace it."

        case FileExtensions.HTML:
            transcriptBtn.image = symbol("chevron.left.slash.chevron.right")?.imageTint(withColor: setColor)
            transcriptBtn.toolTip = "Transcript: a web page. Choose again to replace it."

        default:
            transcriptBtn.image = symbol("doc.text")?.imageTint(withColor: unsetColor)
            transcriptBtn.toolTip = "Transcript: choose a PDF or an HTML file."

        }

        removeTranscriptBtn.isHidden = ext == nil

    }

    private func symbol(_ name: String) -> NSImage? {

        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Transcript")

        return image?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 42, weight: .regular))

    }

    /// The transcript panel takes either form, and setting one clears the other so the package never
    /// holds two transcripts for the player to choose between.
    private func openTranscriptBrowser() {

        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedFileTypes = Downloadable.transcriptExtensions

        panel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in

            guard result == NSApplication.ModalResponse.OK,
                  let url = panel.url,
                  let doc = self.doc,
                  let name = doc.fileURL?.deletingPathExtension().lastPathComponent else { return }

            let ext = url.pathExtension.lowercased()

            guard Downloadable.isTranscript(ext) else { return }

            guard Downloadable.canName(transcript: ext, documentName: name) else {

                Util.shared.showAlert(
                    message: "A web transcript can't be added to a presentation named \u{201C}\(name)\u{201D}",
                    informative: "Its transcript would have to be called \(Downloadable.fileName(documentName: name, ext: ext)), which is the name the presentation itself uses. Rename the presentation, or use a PDF transcript instead.",
                    style: .warning
                )

                return

            }

            for existing in Downloadable.transcriptFileNames(documentName: name) {

                if doc.fileWrapperExistsInRoot(name: existing) {
                    doc.removeRootDirFile(file: existing)
                }

            }

            doc.addDownloadFile(name: Downloadable.fileName(documentName: name, ext: ext), url: url)

            self.showTranscript(ext)

            doc.save(nil)

        })

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
                    self.doc!.removeRootDirFile(file: fileName)
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
