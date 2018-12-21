//
//  PageDetailsViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/3/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser
import WebKit
import AVFoundation

class ImageAudioViewItem: NSCollectionViewItem, NSTextViewDelegate, AVAudioPlayerDelegate {
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var imgSrcTxtfld: NSTextField!
    @IBOutlet weak var audioSrcTxtfld: NSTextField!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var imageWell: NSImageView!
    @IBOutlet weak var svgView: WKWebView!
    @IBOutlet var notesTxtvw: NSTextView!
    @IBOutlet weak var pageNumLbl: NSTextField!
    @IBOutlet weak var hiddenPageNum: NSTextField!
    @IBOutlet weak var hiddenPageIndex: NSTextField!
    @IBOutlet weak var audioPlayBtn: NSButton!
    @IBOutlet weak var audioSlider: NSSlider!
    @IBOutlet weak var audioTimeRemaining: NSTextField!
    
    private var doc: Document?
    private var currentPageObj: Page?
    private var fileType: String?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        notesTxtvw.delegate = self
        
    }
    
    override func viewWillAppear() {
        
        doc = (NSDocumentController.shared.currentDocument as? Document)!
        currentPageObj = doc!.getXmlObj().getSectionAsPages()[Int(hiddenPageIndex.stringValue)!]
        hiddenPageNum.stringValue = String(currentPageObj!.num)
        pageNumLbl.stringValue = "Page \(currentPageObj!.num): \(titleTxtfld.stringValue)"
        fileType = doc!.getXmlObj().pageImgFormat
        
        if (fileType! == "svg") {
            
            imageWell.isHidden = true
            svgView.isHidden = false
            
        } else {
            
            imageWell.isHidden = false
            svgView.isHidden = true
            
        }
        
    }
    
    override func viewDidAppear() {
        
        // display image
        if !imgSrcTxtfld.stringValue.isEmpty {
            
            if let imgFile = doc!.getFileWrapper(name: "\(currentPageObj!.src).\(fileType!)", at: "pages") {
                
                if (fileType! == "svg") {
                    
                    let svg = String(data: imgFile.regularFileContents!, encoding: String .Encoding.utf8)
                    self.svgView.loadHTMLString(Util.shared.formatSvg(str: svg!), baseURL: URL(string: "http://localhost"))
                    
                } else {
                    
                    imageWell.image = NSImage(data: imgFile.regularFileContents!)
                    
                }
                
            } else {
                
                let alert = NSAlert()
                
                alert.messageText = "Image Loading Error"
                alert.informativeText = "The file \"\(imgSrcTxtfld.stringValue)\" cannot be loaded or is not found."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
                
            }
            
        }
        
        // set audio
        if !audioSrcTxtfld.stringValue.isEmpty {
            
            if let audioFile = doc!.getFileWrapper(name: "\(currentPageObj!.src).mp3", at: "audio") {
                
                do {
                    
                    audioPlayer = try AVAudioPlayer(data: audioFile.regularFileContents!)
                    audioPlayer!.delegate = self
                    
                    audioSlider.minValue = 0.0
                    audioSlider.maxValue = audioPlayer!.duration
                    
                    audioTimeRemaining.stringValue = "-" + Util.shared.timeAsString(timeInterval: ((audioPlayer?.duration)! - audioPlayer!.currentTime))
                    
                } catch let error as NSError {
                    
                    print(error.localizedDescription)
                    
                }
                
            }
            
        }
        
    }
    
    @IBAction func titleChange(_ sender: NSTextField) {
        
        if (sender.stringValue != currentPageObj!.title) {
            
            pageNumLbl.stringValue = "Page \(currentPageObj!.num): \(titleTxtfld.stringValue)"
            
            currentPageObj?.title = sender.stringValue
            doc!.updateChangeCount(.changeDone)
            
            (NSApplication.shared.mainWindow?.contentViewController as? PresentationViewController)!.updatePages()
            
        }
        
    }
    
    @IBAction func browseImgSrc(_ sender: NSButton) {
        
        let fileType = "\((NSDocumentController.shared.currentDocument as? Document)!.getXmlObj().pageImgFormat)"
        
        if (!self.imgSrcTxtfld.stringValue.isEmpty) {
            
            let confirmationAlert = NSAlert()
            confirmationAlert.messageText = "Are you sure?"
            confirmationAlert.informativeText = "Image replacement cannot be undone."
            confirmationAlert.alertStyle = .warning
            confirmationAlert.addButton(withTitle: "Yes")
            confirmationAlert.addButton(withTitle: "Cancel")
            
            let res = confirmationAlert.runModal()
            
            if res == NSApplication.ModalResponse.alertFirstButtonReturn {
                
                self.openImgBrowsePanel(type: fileType)
                
            }
            
        } else {
            
            self.openImgBrowsePanel(type: fileType)
            
        }
        
    }
    
    private func openImgBrowsePanel(type: String) {
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = false
        imgBrowsePanel.canChooseDirectories = false
        imgBrowsePanel.allowedFileTypes = [type]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if (result == NSApplication.ModalResponse.OK) {
                
                self.imgSrcTxtfld.stringValue = imgBrowsePanel.url!.absoluteString
                
                if type == "svg" {
                    
                    do {
                        
                        let svg = try String(contentsOf: imgBrowsePanel.url!, encoding: String.Encoding.utf8)
                        self.svgView.loadHTMLString(Util.shared.formatSvg(str: svg), baseURL: URL(string: "http://localhost"))
                        
                    } catch let error as NSError {
                        
                        print(error.localizedDescription)
                        
                    }
                    
                } else {
                    
                    self.imageWell.image = NSImage(byReferencing: imgBrowsePanel.url!)
                    
                }
                
                let doc = (NSDocumentController.shared.currentDocument as? Document)!
                let fileName = "page\(Util.shared.formatPageNum(num: Int(self.hiddenPageNum.stringValue)!))"
                
                doc.getXmlObj().getSectionAsPages()[Int(self.hiddenPageIndex.stringValue)!].src = fileName
                doc.addAssetFile(name: "\(fileName).\(type)", path: imgBrowsePanel.url!, to: "pages")
                doc.updateChangeCount(.changeDone)
                
            }
            
        } )
        
    }
    
    @IBAction func playPauseAudio(_ sender: NSButton) {
        
        if (audioPlayer!.isPlaying) {
            
            audioPlayer?.pause()
            sender.title = "Play"
            updateView()
            timer?.invalidate()
            
        } else {
            
            audioPlayer?.play()
            sender.title = "Pause"
            startTimer()
            
        }
        
    }
    
    @IBAction func onAudioScrub(_ sender: NSSlider) {
        
        print(sender.doubleValue)
        audioPlayer!.currentTime = sender.doubleValue
        print(audioPlayer!.currentTime)
        
    }
    
    @IBAction func browseAudioSrc(_ sender: NSButton) {
        
        print("Audio browse click")
        
    }
    
    func textDidEndEditing(_ notification: Notification) {
        
        guard let textView = notification.object as? NSTextView else { return }
        
        if (textView.string != currentPageObj!.notes) {
            currentPageObj?.notes = textView.string
        }
        
    }
    
    private func startTimer() {
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateViewWithTimer), userInfo: nil, repeats: true)
    }
    
    @objc func updateViewWithTimer(timer: Timer) {
        updateView()
    }
    
    private func updateView() {
        
        audioTimeRemaining.stringValue = "-" + Util.shared.timeAsString(timeInterval: (audioPlayer!.duration - audioPlayer!.currentTime))
        audioSlider.doubleValue = audioPlayer!.currentTime
        
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        audioPlayBtn.title = "Play"
        timer?.invalidate()
        updateView()
        
    }
    
}
