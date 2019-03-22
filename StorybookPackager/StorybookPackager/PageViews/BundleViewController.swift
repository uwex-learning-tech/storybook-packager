//
//  BundleViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/18/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import WebKit
import AVFoundation
import SbXmlParser

class BundleViewController: NSViewController, AVAudioPlayerDelegate, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var svgImageView: WKWebView!
    @IBOutlet weak var audioPlayerBox: NSBox!
    @IBOutlet weak var audioPlayBtn: NSButton!
    @IBOutlet weak var audioSlider: NSSlider!
    @IBOutlet weak var currentTime: NSTextField!
    @IBOutlet weak var duration: NSTextField!
    @IBOutlet weak var frameTable: NSTableView!
    @IBOutlet weak var addFrameBtn: NSButton!
    @IBOutlet weak var deleteFrameBtn: NSButton!
    
    var fileType: String?
    
    private var currentDocument: Document?
    private var currentPage: Page?
    private var files: Array<FileWrapper> = []
    private var audio: FileWrapper?
    private var frames: Array<String> = []
    private var fileContents: Array<Data> = []
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioBoxTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        imageView.alphaValue = 0
        svgImageView.alphaValue = 0
        
        audioPlayBtn.isEnabled = false
        audioSlider.isEnabled = false
        
        frameTable.dataSource = self
        frameTable.delegate = self
        frameTable.target = self
        frameTable.selectionHighlightStyle = .regular
        
        let imgFileUrl = Bundle.main.url(forResource: ObjIdentifiers.PAGE_IMAGE_PLACEHOLDER, withExtension: FileExtensions.PNG)?.absoluteURL
        let data = NSData(contentsOf: imgFileUrl!)?.base64EncodedString(options: NSData.Base64EncodingOptions.endLineWithLineFeed)
        
        svgImageView.loadHTMLString(Util.shared.formatImgHtml(base64: data!), baseURL: URL(string: "http://localhost"))
        
        // add notification
        NotificationCenter.default.addObserver(self, selector: #selector(self.mouseOver), name: Notification.Name("mouseOver"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.mouseOut), name: Notification.Name("mouseOut"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.loadFrames), name: Notification.Name("loadFrames"), object: nil)
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        currentDocument = NSDocumentController.shared.currentDocument as? Document
        
        let index = currentDocument!.currentPageIndex.first!
        currentPage = currentDocument!.getXmlObjPages()[index]
        
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        svgImageView.loadHTMLString("", baseURL: URL(string: "http://localhost"))
        audioPlayerBox.alphaValue = 1
        audioBoxTimer?.invalidate()
        timer?.invalidate()
        audioPlayer?.stop()
        audioPlayer = nil
        audioPlayBtn.image = NSImage(named: "play_icn")
        audioPlayBtn.isEnabled = false
        audioSlider.isEnabled = false
        currentTime.stringValue = "00:00"
        duration.stringValue = "00:00"
        audioSlider.doubleValue = 0.0
        
    }
    
    /** table data source **/
    func numberOfRows(in tableView: NSTableView) -> Int {
        
        return frames.count
        
    }
    
    /** table delegate **/
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        if ( tableColumn == frameTable.tableColumns[0] ) {
            
            if let cell = frameTable.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ObjIdentifiers.FRAME_CELL), owner: self ) as? FrameCellView {
                
                if row <= frames.count - 1 {
                    
                    cell.textField?.stringValue = frames[row]
                    
                }
                
                return cell
                
            }
            
        }
        
        return NSTableCellView()
        
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        
        if frameTable.selectedRow > 0 {
            deleteFrameBtn.isEnabled = true
        } else {
            deleteFrameBtn.isEnabled = false
        }
        
        guard frameTable.selectedRow != -1 else { return }
        displayImage(index: frameTable.selectedRow)
        
        guard audioPlayer != nil else { return }
        
        audioSlider.doubleValue = Util.shared.timeStringToSeconds(time: frames[frameTable.selectedRow])
        onAudioScrub(audioSlider)
        
    }
    
    /** IB Actions **/
    
    @IBAction func addFrame(_ sender: NSButton) {
        
        guard currentDocument != nil else { return }
        
        var currentTime: String = "00:00"
        
        if audioPlayer != nil {
            audioPlayer!.pause()
            currentTime = Util.shared.timeAsString(timeInterval: audioPlayer!.currentTime)
        }
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = false
        imgBrowsePanel.canChooseDirectories = false
        imgBrowsePanel.allowedFileTypes = [fileType!]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if result == NSApplication.ModalResponse.OK {
                
                let fileName = self.currentDocument!.getFileNamePrefix() +  Util.shared.formatPageNum(num: self.currentPage!.number + 1) + "-" + String(self.frameTable.numberOfRows + 1) + "." + self.fileType!
                
                self.currentDocument!.addAssetsWrappersFile(name: fileName, path: imgBrowsePanel.url!, to: FileNames.PAGES_DIR)
                
                self.currentPage!.addFrame(frame: currentTime)
                self.reloadFrameTable()
                self.setImageData()
                self.frameTable.selectRowIndexes([self.frameTable.numberOfRows - 1], byExtendingSelection: false)
                
                self.currentDocument!.updateChangeCount(.changeDone)
                
            }
            
        } )
        
    }
    
    @IBAction func deleteFrame(_ sender: NSButton) {
        
        if frameTable.selectedRowIndexes.count >= 1 {
            
            guard currentDocument != nil else { return }
            
            var count = 1;
            let selectedRowIndex = frameTable.selectedRowIndexes.first!
            
            let delFile = currentDocument?.getAssetFileWrapper(name: "\(currentPage!.src)-\(selectedRowIndex + 1).\(fileType!)", at: FileNames.PAGES_DIR)
            delFile!.filename = "DEL-\(selectedRowIndex + 1).\(fileType!)"

            for (index, file) in files.enumerated() {
                
                if file.filename!.contains("DEL") == true {
                    currentDocument!.removeFromAssetsWrapper(file: file, at: FileNames.PAGES_DIR)
                    continue
                }
                
                currentDocument!.removeFileFromAssetsDir(file: "\(currentPage!.src)-\(index + 1).\(fileType!)", subDir: FileNames.PAGES_DIR)
                currentDocument!.addAssetsWrappersFile(name: currentPage!.src + "-" + String(count) + "." + fileType!, file: file, to: FileNames.PAGES_DIR)

                count = count + 1
                
            }
            
            currentPage!.frames.remove(at: frameTable.selectedRowIndexes.first!)
            frames = self.currentPage!.frames
            setImageData()
            
            if selectedRowIndex > 0 && selectedRowIndex < frames.count {
                displayImage(index: selectedRowIndex - 1)
            } else {
                displayImage(index: 0)
            }

            frameTable.reloadData()
            currentDocument!.updateChangeCount(.changeDone)
            
        }
        
    }
    
    @IBAction func onAudioScrub(_ sender: NSSlider) {
        
        if audioPlayer != nil {
            audioPlayer!.currentTime = sender.doubleValue
            currentTime.stringValue = Util.shared.timeAsString(timeInterval: sender.doubleValue)
        }
        
    }
    
    @IBAction func playPauseAudio(_ sender: NSButton) {
        
        if (audioPlayer!.isPlaying) {
            
            audioPlayer?.pause()
            sender.image = NSImage(named: "play_icn")
            updateView()
            timer?.invalidate()
            
            audioPlayerBox.alphaValue = 1
            
            if audioBoxTimer != nil {
                audioBoxTimer!.invalidate()
            }
            
        } else {
            
            audioPlayer?.play()
            sender.image = NSImage(named: "pause_icn")
            startTimer()
            
        }
        
    }
    
    @IBAction func frameTimeChange(_ sender: NSTextField) {
        
        guard currentDocument != nil else { return }
        
        currentPage!.frames[frameTable.selectedRow] = sender.stringValue
        frames = currentPage!.frames
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    @IBAction func addFrameImage(_ sender: NSButton) {
        
        print(frameTable.clickedRow as Any)
        
//        let imgBrowsePanel = NSOpenPanel()
//        imgBrowsePanel.allowsMultipleSelection = false
//        imgBrowsePanel.canChooseDirectories = false
//        imgBrowsePanel.allowedFileTypes = [fileType!]
//
//        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
//
//            if result == NSApplication.ModalResponse.OK {
//
//                self.currentDocument!.addAssetsWrappersFile(name: "\(self.currentPage!.src)-\(self.frameTable.numberOfRows + 1).\(self.fileType!)", path: imgBrowsePanel.url!, to: FileNames.PAGES_DIR)
//                self.setImageData()
//                self.currentDocument!.updateChangeCount(.changeDone)
//
//            }
//
//        } )
        
    }
    
    @objc func mouseOver(_ sender: Notification) {
        
        guard (sender.object as? NSWindow) == self.view.window else { return }
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 1
            
            audioPlayerBox.animator().alphaValue = 1

            if audioBoxTimer != nil {
                audioBoxTimer!.invalidate()
            }
            
        })
        
    }
    
    @objc func mouseOut(_ sender: Notification) {
        
        guard (sender.object as? NSWindow) == self.view.window else { return }
        
        if audioPlayer != nil && audioPlayer!.isPlaying {
            setFadeAudioBoxOut()
        }
        
    }
    
    @objc func loadFrames(_ sender: Notification) {
        
        guard let document = sender.object as? Document else { return }
        guard currentDocument != nil else { return }
        
        if document == currentDocument! {
            
            if !currentPage!.src.isEmpty {
                
                audio = document.getAssetFileWrapper(name: "\(currentPage!.src).\(FileExtensions.MP3)", at: FileNames.AUDIO_DIR)
                
                setAudio()
                
            } else {
                
                currentPage!.src = document.getFileNamePrefix() + String(currentPage!.number + 1)
                
            }
            
            reloadFrameTable()
            setImageData()
            displayImage(index: 0) // display the first frame image
            
        }
        
    }
    
    private func setImageData() {
        
        files = {() -> Array<FileWrapper> in
            
            var fws: Array<FileWrapper> = []
            
            for (index, _) in frames.enumerated() {
                guard let file = currentDocument!.getAssetFileWrapper(name: "\(currentPage!.src)-\(index + 1).\(fileType!)", at: FileNames.PAGES_DIR) else {
                    fws.append(FileWrapper())
                    continue
                }
                fws.append(file)
            }
            
            return fws
            
        }()
        
        fileContents = []
        files.forEach({fileContents.append($0.regularFileContents!)})
    
    }
    
    private func displayImage(index: Int) {
        
        if !files.isEmpty {
            
            if fileContents[index].count > 0 {
                
                if fileType == FileExtensions.SVG {
                    
                    let svg = String(data: fileContents[index], encoding: String.Encoding.utf8)
                    svgImageView.loadHTMLString(Util.shared.formatSvg(str: svg!), baseURL: URL(string: "http://localhost"))
                    
                } else {
                    
                    imageView.image = NSImage(data: fileContents[index])
                    
                }
                
            }
            
        }
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 1
            
            if fileType == FileExtensions.SVG {
                svgImageView.animator().alphaValue = 1
            } else {
                imageView.animator().alphaValue = 1
            }
            
        }, completionHandler: {
            
            if self.fileType == FileExtensions.SVG {
                
                self.imageView.isHidden = true
                self.svgImageView.animator().isHidden = false
                
            } else {
                
                self.svgImageView.isHidden = true
                self.imageView.animator().isHidden = false
                
            }
            
        })
        
    }
    
    private func setAudio() {
        
        // set audio
        if audio != nil {
            
            do {
                
                audioPlayer = try AVAudioPlayer(data: audio!.regularFileContents!)
                audioPlayer!.delegate = self
                
                audioSlider.minValue = 0.0
                audioSlider.maxValue = audioPlayer!.duration
                
                duration.stringValue = Util.shared.timeAsString(timeInterval: audioPlayer!.duration)
                currentTime.stringValue = Util.shared.timeAsString(timeInterval: audioPlayer!.currentTime)
                
                audioPlayBtn.isEnabled = true
                audioSlider.isEnabled = true
                
            } catch let error as NSError {
                
                print(error.localizedDescription)
                
            }
            
        }
        
    }
    
    private func reloadFrameTable() {
        
        frames = currentPage!.frames
        frameTable.reloadData()
    
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.updateViewWithTimer), userInfo: nil, repeats: true)
    }
    
    @objc func updateViewWithTimer(timer: Timer) {
        updateView()
    }
    
    private func updateView() {
        
        currentTime.stringValue = Util.shared.timeAsString(timeInterval: audioPlayer!.currentTime)
        audioSlider.doubleValue = audioPlayer!.currentTime
        
    }
    
    private func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        audioPlayBtn.image = NSImage(named: "play_icn")
        timer?.invalidate()
        updateView()
        
    }
    
    private func setFadeAudioBoxOut() {
        
        audioBoxTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.fadeAudioBoxOut), userInfo: nil, repeats: false)
        
    }
    
    @objc private func fadeAudioBoxOut() {
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 1
            
            audioPlayerBox.animator().alphaValue = 0
            
        }, completionHandler: {
            
            self.audioBoxTimer?.invalidate()
            
        })
        
    }
    
}
