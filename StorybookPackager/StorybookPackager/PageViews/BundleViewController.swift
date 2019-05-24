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
import sbplus_xml_parser

class BundleViewController: NSViewController, AVAudioPlayerDelegate, NSTableViewDelegate, NSTableViewDataSource, WKNavigationDelegate {
    
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
    @IBOutlet weak var preventControlFadeCheckBox: NSButton!
    
    var fileType: String?
    var currentDocument: Document?

    private var files: Array<FileWrapper> = []
    private var audio: FileWrapper?
    private var frames: Array<String> = []
    private var fileContents: Array<Data> = []
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioBoxTimer: Timer?
    private var currentFrameIndex: Int = -1
    private var shouldScrub: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        imageView.alphaValue = 0
        
        svgImageView.alphaValue = 0
        svgImageView.navigationDelegate = self
        svgImageView.setValue(false, forKey: "drawsBackground")
        
        audioPlayBtn.isEnabled = false
        audioSlider.isEnabled = false
        
        frameTable.dataSource = self
        frameTable.delegate = self
        frameTable.target = self
        frameTable.selectionHighlightStyle = .regular
        
        // add notification
        NotificationCenter.default.addObserver(self, selector: #selector(self.mouseOver), name: Notification.Name("mouseOver"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.mouseOut), name: Notification.Name("mouseOut"), object: nil)
        
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
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
        currentFrameIndex = -1
        
    }
    
    func loadBundleFrames() {
        
        guard currentDocument != nil else { return }
        guard let index = currentDocument?.currentPageIndex.first else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        
        if !currentPage.src.isEmpty {
            
            audio = currentDocument!.getAssetFileWrapper(name: "\(currentPage.src).\(FileExtensions.MP3)", at: FileNames.AUDIO_DIR)
            setAudio()
            
        } else {
            
            currentPage.src = currentDocument!.getFileNamePrefix() + String(currentPage.number + 1)
            
        }
        
        reloadFrameTable()
        setImageData()
        displayImage(index: 0) // display the first frame image
        
    }
    
    /** table data source **/
    func numberOfRows(in tableView: NSTableView) -> Int {
        return frames.count
    }
    
    /** table delegate **/
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        if ( tableColumn == frameTable.tableColumns[0] ) {
            
            if let cell = frameTable.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ObjIdentifiers.FRAME_CELL), owner: self ) as? FrameCellView {
                
                cell.frameNumber.stringValue = String(row + 1)
                
                if row == 0 {
                    cell.updateFrameBtn.isHidden = true
                    cell.updateFrameBtn.isEnabled = false
                }
                
                if row <= frames.count - 1 {
                    
                    if audioPlayer != nil {
                        cell.updateFrameBtn.isEnabled = true
                    } else {
                        cell.updateFrameBtn.isEnabled = false
                    }
                    
                    cell.textField?.stringValue = frames[row]
                    
                }
                
                return cell
                
            }
            
        }
        
        return NSTableCellView()
        
    }
    
    func tableViewSelectionIsChanging(_ notification: Notification) {
        
        guard let info = notification.userInfo else {
            
            shouldScrub = true
            return
        
        }
        
        if let scrub = info["scrub"] as? Bool {
            shouldScrub = scrub
        }
        
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        
        if frameTable.selectedRow > 0 {
            deleteFrameBtn.isEnabled = true
        } else {
            deleteFrameBtn.isEnabled = false
        }

        guard frameTable.selectedRow != -1 else { return }
        
        if audioPlayer == nil {
            
            updateFrameImage(at: frameTable.selectedRow)
            
        } else {
            
            if shouldScrub {
                audioSlider.doubleValue = Util.shared.timeStringToSeconds(time: frames[frameTable.selectedRow])
                onAudioScrub(audioSlider)
                shouldScrub = true
            }
            
        }

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
                
                guard let index = self.currentDocument?.currentPageIndex.first else { return }
                
                let currentPage = self.currentDocument!.getXmlObjPages()[index]
                let fileName = self.currentDocument!.getFileNamePrefix() +  Util.shared.formatPageNum(num: currentPage.number + 1) + "-" + String(self.frameTable.numberOfRows + 1) + "." + self.fileType!
                
                self.currentDocument!.addAssetsWrappersFile(name: fileName, path: imgBrowsePanel.url!, to: FileNames.PAGES_DIR)
                
                do {
                    self.fileContents.append(try Data(contentsOf: imgBrowsePanel.url!))
                } catch let error as NSError {
                    NSLog(error.localizedDescription)
                }
                
                currentPage.addFrame(frame: currentTime)
                
                self.reloadFrameTable()
                self.frameTable.selectRowIndexes([self.frameTable.numberOfRows - 1], byExtendingSelection: false)
                self.currentDocument!.updateChangeCount(.changeDone)
                
            }
            
        } )
        
    }
    
    @IBAction func deleteFrame(_ sender: NSButton) {
        
        if frameTable.selectedRowIndexes.count >= 1 {
            
            guard currentDocument != nil else { return }
            guard let index = currentDocument?.currentPageIndex.first else { return }
            
            let currentPage = currentDocument!.getXmlObjPages()[index]
            let selectedRowIndex = frameTable.selectedRowIndexes.first!
            var count = 1;
            let delFile = currentDocument?.getAssetFileWrapper(name: "\(currentPage.src)-\(selectedRowIndex + 1).\(fileType!)", at: FileNames.PAGES_DIR)
            
            delFile!.filename = "DEL-\(selectedRowIndex + 1).\(fileType!)"

            for (index, file) in files.enumerated() {
                
                guard file.filename != nil else { continue }
                
                if file.filename!.contains("DEL") == true {
                    currentDocument!.removeFromAssetsWrapper(file: file, at: FileNames.PAGES_DIR)
                    continue
                }
                
                currentDocument!.removeFileFromAssetsDir(file: "\(currentPage.src)-\(index + 1).\(fileType!)", subDir: FileNames.PAGES_DIR)
                currentDocument!.addAssetsWrappersFile(name: currentPage.src + "-" + String(count) + "." + fileType!, file: file, to: FileNames.PAGES_DIR)

                count = count + 1
                
            }
            
            currentPage.frames.remove(at: frameTable.selectedRowIndexes.first!)
            frames = currentPage.frames
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
            currentFrameIndex = -1
        }
        
        if audioPlayer!.isPlaying == false {
            updateView()
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
        guard let index = currentDocument?.currentPageIndex.first else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        
        currentPage.frames[frameTable.selectedRow] = sender.stringValue
        frames = currentPage.frames
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    @IBAction func updateFrameTime(_ sender: NSButton) {
        
        guard let index = currentDocument?.currentPageIndex.first else { return }
        
        if let time = audioPlayer?.currentTime {
            
            let currentPage = currentDocument!.getXmlObjPages()[index]
            let row = frameTable.row(for: sender.superview!)
            let timeAsStr = Util.shared.timeAsString(timeInterval: time)

            if timeAsStr != "00:00" && timeAsStr != frames[row]  {
                
                currentPage.frames[row] = timeAsStr
                frames = currentPage.frames
                frameTable.reloadData(forRowIndexes: [row], columnIndexes: [0])
                frameTable.selectRowIndexes([row], byExtendingSelection: false)
                currentDocument!.updateChangeCount(.changeDone)
                
            }
            
        }
        
    }
    
    @IBAction func addFrameImage(_ sender: NSButton) {
        
        guard let index = currentDocument?.currentPageIndex.first else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        let row = frameTable.row(for: sender.superview!)
        
        frameTable.selectRowIndexes([row], byExtendingSelection: false)
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = false
        imgBrowsePanel.canChooseDirectories = false
        imgBrowsePanel.allowedFileTypes = [fileType!]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if result == NSApplication.ModalResponse.OK {
                
                let fileName = self.currentDocument!.getFileNamePrefix() +  Util.shared.formatPageNum(num: currentPage.number + 1) + "-" + String(row + 1) + "." + self.fileType!
                
                self.currentDocument!.addAssetsWrappersFile(name: fileName, path: imgBrowsePanel.url!, to: FileNames.PAGES_DIR)
                self.currentDocument!.updateChangeCount(.changeDone)
                
                do {
                    self.fileContents[row] = try Data(contentsOf: imgBrowsePanel.url!)
                    self.displayImage(index: row)
                } catch let error as NSError {
                    NSLog(error.localizedDescription)
                }
                
            }
            
        } )
        
    }
    
    @IBAction func pinAudioControl(_ sender: NSButton) {
        
        if sender.state == .on {
            fadeAudioBoxIn()
        } else {
            setFadeAudioBoxOut()
        }
        
    }
    
    @objc func mouseOver(_ sender: Notification) {
        
        guard (sender.object as? NSWindow) == self.view.window else { return }
        
        if preventControlFadeCheckBox.state == .off {
        
            NSAnimationContext.runAnimationGroup({
                context in
                context.duration = 0.25
                
                audioPlayerBox.animator().alphaValue = 1

                if audioBoxTimer != nil {
                    audioBoxTimer!.invalidate()
                }
                
            })
            
        }
        
    }
    
    @objc func mouseOut(_ sender: Notification) {
        
        guard (sender.object as? NSWindow) == self.view.window else { return }
        
        if preventControlFadeCheckBox.state == .off {
            
            if audioPlayer != nil && audioPlayer!.isPlaying {
                setFadeAudioBoxOut()
            }
            
        }
        
    }
    
    private func setImageData() {
        
        guard let index = currentDocument?.currentPageIndex.first else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        
        files = {() -> Array<FileWrapper> in
            
            var fws: Array<FileWrapper> = []
            
            for (index, _) in frames.enumerated() {
                guard let file = currentDocument!.getAssetFileWrapper(name: "\(currentPage.src)-\(index + 1).\(fileType!)", at: FileNames.PAGES_DIR) else {
                    fws.append(FileWrapper())
                    continue
                }
                fws.append(file)
            }
            
            return fws
            
        }()
        
        files.forEach({fileContents.append($0.regularFileContents!)})
    
    }
    
    private func displayImage(index: Int) {
        
        if !files.isEmpty {
            
            if fileContents[index].count > 0 {

                if fileType == FileExtensions.SVG {
                    
                    let svgString = String(data: fileContents[index], encoding: .utf8)
                    svgImageView.loadHTMLString(Util.shared.formatSvg(str: svgString!), baseURL: URL(string: "http://localhost"))
                    
                } else {
                    
                    svgImageView.isHidden = true
                    imageView.image = NSImage(data: fileContents[index])
                    Util.shared.animateIn(image: imageView)
                    
                }
                
            }
            
        }
        
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
                
                NSLog(error.localizedDescription)
                
            }
            
        }
        
    }
    
    private func reloadFrameTable() {
        
        guard let index = currentDocument?.currentPageIndex.first else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        frames = currentPage.frames
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
        
        let targetIndex = setFrameImage(index: currentFrameIndex, time: audioPlayer!.currentTime)
        
        if currentFrameIndex != targetIndex {
            
            currentFrameIndex = targetIndex
            
            frameTable.selectRowIndexes([currentFrameIndex], byExtendingSelection: false)
            NotificationCenter.default.post(name: Notification.Name("NSTableViewSelectionIsChangingNotification"), object: frameTable, userInfo: ["scrub":false])
            
            updateFrameImage(at: currentFrameIndex)
            
        }
        
    }
    
    private func updateFrameImage(at: Int) {
        
        if (fileContents.indices.contains(at)) {
            
            if fileType == FileExtensions.SVG {
                
                let svgString = String(data: fileContents[at], encoding: .utf8)
                svgImageView.loadHTMLString(Util.shared.formatSvg(str: svgString!), baseURL: URL(string: "http://localhost"))
                
            } else {
                
                imageView.image = NSImage(data: fileContents[at])
                
            }
            
        }

    }
    
    private func setFrameImage(index: Int, time: TimeInterval) -> Int {
        
        if index < 0 {
            return setFrameImage(index: index + 1, time: time)
        }
        
        if frames.index(after: index) >= frames.count {
            return frames.count - 1
        }
        
        let frameTime = Util.shared.timeStringToSeconds(time: frames[index])
        let nextFrameTime = Util.shared.timeStringToSeconds(time: frames[frames.index(after: index)])
        
        if time < frameTime {
            return setFrameImage(index: index - 1, time: time)
        }
        
        if time >= frameTime && time < nextFrameTime {
            return index
        } else {
            return setFrameImage(index: index + 1, time: time)
        }
        
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
        audioPlayerBox.alphaValue = 1
        audioPlayBtn.image = NSImage(named: "play_icn")
        timer?.invalidate()
        frameTable.selectRowIndexes([0], byExtendingSelection: false)
        updateView()
        displayImage(index: 0)
        currentFrameIndex = -1
        
    }
    
    private func setFadeAudioBoxOut() {
        
        audioBoxTimer = Timer.scheduledTimer(timeInterval: 6, target: self, selector: #selector(self.fadeAudioBoxOut), userInfo: nil, repeats: false)
        
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
    
    private func fadeAudioBoxIn() {
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 0.25
            
            audioPlayerBox.animator().alphaValue = 1
            
            if audioBoxTimer != nil {
                audioBoxTimer!.invalidate()
            }
            
        })
        
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        webView.takeSnapshot(with: .none, completionHandler: {(img, error) in
            
            if img != nil {
                webView.isHidden = true
                self.imageView.image = img!
                Util.shared.animateIn(image: self.imageView)
            }
            
        })
        
    }
    
}
