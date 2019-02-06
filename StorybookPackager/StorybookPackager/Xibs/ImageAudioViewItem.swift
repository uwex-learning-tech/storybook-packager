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

class ImageAudioViewItem: NSCollectionViewItem, NSTextViewDelegate, NSTextFieldDelegate, AVAudioPlayerDelegate {
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var imageWell: NSImageView!
    @IBOutlet weak var svgView: WKWebView!
    @IBOutlet weak var notesTxtvw: NSTextView!
    @IBOutlet weak var pageNumLbl: NSTextField!
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
        
        titleTxtfld.delegate = self
        
        audioPlayBtn.isEnabled = false
        audioSlider.isEnabled = false
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        doc = (NSDocumentController.shared.currentDocument as? Document)!        
        currentPageObj = doc!.getXmlObjPages()[doc!.currentPageIndex.first!.item]
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(currentPageObj!.title)"
        fileType = doc!.getXmlObj().pageImgFormat
        
        typeBtn.selectItem(at: Util.shared.getPageTypeIndex(type: currentPageObj!.type, collection: typeBtn.itemTitles))
        
        if (fileType! == FileExtensions.SVG) {
            
            imageWell.isHidden = true
            svgView.isHidden = false
            
        } else {
            
            imageWell.isHidden = false
            svgView.isHidden = true
            
        }
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // display image
        if !currentPageObj!.src.isEmpty {
            
            if let imgFile = doc!.getAssetsWrapper(name: "\(currentPageObj!.src).\(fileType!)", at: FileNames.PAGES_DIR) {
                
                if (fileType! == FileExtensions.SVG) {
                    
                    let svg = String(data: imgFile.regularFileContents!, encoding: String .Encoding.utf8)
                    self.svgView.loadHTMLString(Util.shared.formatSvg(str: svg!), baseURL: URL(string: "http://localhost"))
                    
                } else {
                    
                    imageWell.image = NSImage(data: imgFile.regularFileContents!)
                    
                }
                
            }
            
        } else {
            
            if fileType! == FileExtensions.SVG {
                
                let imgFileUrl = Bundle.main.url(forResource: ObjIdentifiers.PAGE_IMAGE_PLACEHOLDER, withExtension: FileExtensions.PNG)?.absoluteURL
                let data = NSData(contentsOf: imgFileUrl!)?.base64EncodedString(options: NSData.Base64EncodingOptions.endLineWithLineFeed)
                self.svgView.loadHTMLString(Util.shared.formatImgHtml(base64: data!), baseURL: URL(string: "http://localhost"))
                
            }
            
        }
        
        // set audio
        if let audioFile = doc!.getAssetsWrapper(name: "\(currentPageObj!.src).\(FileExtensions.MP3)", at: FileNames.AUDIO_DIR) {
            
            do {
                
                audioPlayer = try AVAudioPlayer(data: audioFile.regularFileContents!)
                audioPlayer!.delegate = self
                
                audioSlider.minValue = 0.0
                audioSlider.maxValue = audioPlayer!.duration
                
                audioTimeRemaining.stringValue = "-" + Util.shared.timeAsString(timeInterval: ((audioPlayer?.duration)! - audioPlayer!.currentTime))
                
                audioPlayBtn.isEnabled = true
                audioSlider.isEnabled = true
                
            } catch let error as NSError {
                
                print(error.localizedDescription)
                
            }
            
        }
        
    }
    
    func controlTextDidChange(_ obj: Notification) {
        
        guard let tf = (obj.object as? NSTextField) else { return }
        
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(tf.stringValue)"
        
        currentPageObj?.title = tf.stringValue
        doc!.updateChangeCount(.changeDone)
        (NSApplication.shared.mainWindow?.contentViewController as? PresentationViewController)!.refreshCurrentPage()
        
    }
    
    @IBAction func browseImgSrc(_ sender: NSButton) {
        
        let fileType = "\((NSDocumentController.shared.currentDocument as? Document)!.getXmlObj().pageImgFormat)"
        self.openBrowsePanel(type: fileType)
        
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
        audioPlayer!.currentTime = sender.doubleValue
    }
    
    @IBAction func browseAudioSrc(_ sender: NSButton) {
        self.openBrowsePanel(type: FileExtensions.MP3)
    }
    
    private func openBrowsePanel(type: String) {
        
        let browsePanel = NSOpenPanel()
        
        browsePanel.allowsMultipleSelection = false
        browsePanel.canChooseDirectories = false
        browsePanel.allowedFileTypes = [type]
        
        browsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if (result == NSApplication.ModalResponse.OK) {
                
                var directory = FileNames.PAGES_DIR
                
                if (type != FileExtensions.MP3) {
                    
                    if type == FileExtensions.SVG {
                        
                        do {
                            
                            let svg = try String(contentsOf: browsePanel.url!, encoding: String.Encoding.utf8)
                            self.svgView.loadHTMLString(Util.shared.formatSvg(str: svg), baseURL: URL(string: "http://localhost"))
                            
                        } catch let error as NSError {
                            
                            print(error.localizedDescription)
                            
                        }
                        
                    } else {
                        
                        self.imageWell.image = NSImage(byReferencing: browsePanel.url!)
                        
                    }
                    
                } else {
                    
                    directory = FileNames.AUDIO_DIR
                    
                    do {
                        
                        self.audioPlayer = try AVAudioPlayer(contentsOf: browsePanel.url!)
                        
                        self.audioSlider.minValue = 0.0
                        self.audioSlider.maxValue = self.audioPlayer!.duration
                        
                        self.audioTimeRemaining.stringValue = "-" + Util.shared.timeAsString(timeInterval: ((self.audioPlayer?.duration)! - self.audioPlayer!.currentTime))
                        
                        self.audioPlayBtn.isEnabled = true
                        self.audioSlider.isEnabled = true
                        
                    } catch let error as NSError {
                        
                        print(error.localizedDescription)
                        
                    }
                    
                }
                
                let doc = (NSDocumentController.shared.currentDocument as? Document)!
                let page = doc.getXmlObjPages()[doc.currentPageIndex.first!.item]
                let fileName = "page\(Util.shared.formatPageNum(num: page.number + 1))"
                
                page.src = fileName
                doc.addAssetsWrappersFile(name: "\(fileName).\(type)", path: browsePanel.url!, to: directory)
                doc.updateChangeCount(.changeDone)
                
            }
            
        } )
        
    }
    
    func textDidEndEditing(_ notification: Notification) {
        
        guard let textView = notification.object as? NSTextView else { return }
        
        if (textView.string != currentPageObj!.notes) {
            currentPageObj?.notes = textView.string
        }
        
    }
    
    private func startTimer() {
        
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.updateViewWithTimer), userInfo: nil, repeats: true)
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
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        svgView.loadHTMLString("", baseURL: URL(string: "http://localhost"))
        timer?.invalidate()
        audioPlayer?.stop()
        audioPlayer = nil
        audioPlayBtn.title = "Play"
        audioPlayBtn.isEnabled = false
        audioSlider.isEnabled = false
        audioTimeRemaining.stringValue = "-00:00"
        audioSlider.doubleValue = 0.0
        
    }
    
    @IBAction func pageTypeChange(_ sender: NSPopUpButton) {
        
        let type = Util.shared.formatPageTypeString(string: sender.selectedItem!.title)
        
        guard type != self.currentPageObj!.type else { return }
        
        self.currentPageObj!.type = type
        doc!.updateChangeCount(.changeDone)
        
        let presentationController = (NSApplication.shared.mainWindow?.contentViewController as? PresentationViewController)!
        
        presentationController.updatePage()
        
    }
}
