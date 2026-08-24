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
    /// Set by PageViewController before the slide is loaded; nil when the slide has no captions.
    var captions: CaptionTrack?

    private var captionOverlay: CaptionOverlayView?

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
        // .fileURL rather than the NSFilenamesPboardType string the older drop views read: it is
        // the same Finder drag either way, and this is the form readObjects(forClasses:) takes.
        frameTable.registerForDraggedTypes([.fileURL])
        
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
        audioPlayBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
        audioPlayBtn.isEnabled = false
        audioSlider.isEnabled = false
        currentTime.stringValue = "00:00"
        duration.stringValue = "00:00"
        audioSlider.doubleValue = 0.0
        captionOverlay?.show(nil)
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
                    cell.textField?.isEditable = false
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
        
        // Any row but frame 1 can go, so the button follows the selection as a whole rather than
        // its last row — selecting 1 through 4 still offers to delete 2, 3 and 4.
        deleteFrameBtn.isEnabled = frameTable.selectedRowIndexes.contains(where: { $0 > 0 })

        guard frameTable.selectedRow != -1 else { return }
        
        // Several rows selected is someone picking frames to delete, not asking to be taken to a
        // point in the narration — dragging the playhead along under them as they shift-click fights
        // the selection they are building. The preview still follows the row they touched last.
        guard frameTable.selectedRowIndexes.count == 1 else {
            
            updateFrameImage(at: frameTable.selectedRow)
            return
            
        }
        
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
    
    /** table drag and drop **/
    
    // Images dropped on the frame list become new frames at the drop point. Only an outside drag
    // means anything here — the rows themselves are not draggable, so a drag that started in this
    // table has nothing to do.
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        
        guard info.draggingSource == nil else { return [] }
        guard let urls = droppedImageUrls(from: info), !urls.isEmpty else { return [] }
        
        // Always an insertion, and never above frame 1: the first frame is the 00:00 one the player
        // opens on, and the parser puts it back at the top regardless of what is stored.
        tableView.setDropRow(frames.isEmpty ? 0 : max(row, 1), dropOperation: .above)
        
        return .copy
        
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        
        guard let urls = droppedImageUrls(from: info), !urls.isEmpty else { return false }
        
        return insertFrames(from: urls, at: row)
        
    }
    
    // The dragged files, or nil unless every one of them is in the presentation's image format —
    // one wrong file rejects the whole drop rather than silently importing part of it. ".jpeg" and
    // ".jpg" are the same format, so a JPG presentation takes either spelling.
    private func droppedImageUrls(from info: NSDraggingInfo) -> Array<URL>? {
        
        guard let expectedExt = fileType else { return nil }
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? Array<URL>, !urls.isEmpty else { return nil }
        
        for url in urls {
            guard Util.shared.sameImageFormat(url.pathExtension, expectedExt) else { return nil }
        }
        
        return urls
        
    }
    
    // Adds the dropped images as frames at `row`, shifting the frames below it down. The timecodes
    // are worked out first, so a drop that cannot be given times leaves the slide untouched.
    private func insertFrames(from urls: Array<URL>, at row: Int) -> Bool {
        
        guard currentDocument != nil else { return false }
        guard let index = currentDocument?.currentPageIndex.first else { return false }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        // Finder hands the files over in its own order, and a plain sort reads "img10" as coming
        // before "img2" — the numbering in the names is what the author means by the sequence.
        let sorted = urls.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })
        // AppKit hands back the row validateDrop set, but an index that fell outside the list
        // would trap rather than misbehave, so it is pinned to the list either way.
        let insertIndex = frames.isEmpty ? 0 : min(max(row, 1), frames.count)
        
        guard let times = newFrameTimes(count: sorted.count, insertingAt: insertIndex) else { return false }
        
        let src = currentPage.src
        let existingCount = frames.count
        
        // Walked backwards so no two frames ever want the same name at the same moment.
        var i = existingCount - 1
        
        while i >= insertIndex {
            
            if let file = currentDocument!.getAssetFileWrapper(name: "\(src)-\(i + 1).\(fileType!)", at: FileNames.PAGES_DIR) {
                
                currentDocument!.removeFileFromAssetsDir(file: "\(src)-\(i + 1).\(fileType!)", subDir: FileNames.PAGES_DIR)
                currentDocument!.addAssetsWrappersFile(name: "\(src)-\(i + 1 + sorted.count).\(fileType!)", file: file, to: FileNames.PAGES_DIR)
                
            }
            
            i -= 1
            
        }
        
        // The "~" copies hold the bytes a slide is renamed from when it moves in the outline, and
        // one is only made if it isn't there already. A leftover from an import still holds the
        // pre-renumbering image, and would quietly put the old images back the next time this slide
        // is reordered — so they go now and get made fresh when they are next needed.
        for n in 0..<(existingCount + sorted.count) {
            currentDocument!.removeFileFromAssetsDir(file: "~\(src)-\(n + 1).\(fileType!)", subDir: FileNames.PAGES_DIR)
        }
        
        for (offset, url) in sorted.enumerated() {
            currentDocument!.addAssetsWrappersFile(name: "\(src)-\(insertIndex + offset + 1).\(fileType!)", path: url, to: FileNames.PAGES_DIR)
        }
        
        // Held across the whole rebuild, not just the final selection: reloadData() can have AppKit
        // adjust the selection itself as rows appear or disappear under it, and that lands here as a
        // selection change like any other. Selecting a row normally means "take me to that point in
        // the narration", but none of this was a request to move the playhead.
        shouldScrub = false
        
        currentPage.frames.insert(contentsOf: times, at: insertIndex)
        
        reloadFrameTable()
        setImageData()
        
        frameTable.selectRowIndexes([insertIndex], byExtendingSelection: false)
        shouldScrub = true
        
        displayImage(index: insertIndex)
        currentDocument!.updateChangeCount(.changeDone)
        
        return true
        
    }
    
    // Whole-second timecodes for `count` frames landing at `insertIndex`, or nil when the gap they
    // land in has no room to give each one a time of its own — frame times have to stay unique and
    // ascending, so a crowded gap is refused outright rather than half-filled.
    private func newFrameTimes(count: Int, insertingAt insertIndex: Int) -> Array<String>? {
        
        guard count > 0 else { return nil }
        
        if insertIndex == 0 {
            return (0..<count).map({ Util.shared.timeAsString(timeInterval: TimeInterval($0)) })
        }
        
        let prev = Int(Util.shared.timeStringToSeconds(time: frames[insertIndex - 1]))
        
        // Dropped at the end there is nothing to fit between, so the frames simply follow on a
        // second apart. The narration's length is not checked here, and the + button doesn't either.
        if insertIndex == frames.count {
            return (1...count).map({ Util.shared.timeAsString(timeInterval: TimeInterval(prev + $0)) })
        }
        
        let next = Int(Util.shared.timeStringToSeconds(time: frames[insertIndex]))
        
        guard next - prev - 1 >= count else {
            
            // Off the drop's call stack: this runs while the drag session is still unwinding, and
            // an app-modal alert raised from there holds the drag source — Finder, usually — until
            // someone dismisses it. The drop itself still fails immediately.
            let informative = "There isn't room between \(frames[insertIndex - 1]) and \(frames[insertIndex]) for \(count) image\(count == 1 ? "" : "s"). Move the following frame later, or drop fewer images."
            
            DispatchQueue.main.async {
                Util.shared.showAlert(message: "Not Enough Room!", informative: informative, style: .critical)
            }
            
            return nil
            
        }
        
        var times: Array<String> = []
        var last = prev
        
        for n in 1...count {
            
            // Spread across the gap, then held to a second past the frame before it and far enough
            // ahead of the next frame to leave room for the ones still to be placed. The gap was
            // checked above, so those two bounds cannot cross.
            var second = prev + Int((Double(next - prev) * Double(n) / Double(count + 1)).rounded())
            
            second = max(second, last + 1)
            second = min(second, next - 1 - (count - n))
            
            times.append(Util.shared.timeAsString(timeInterval: TimeInterval(second)))
            last = second
            
        }
        
        return times
        
    }
    
    /** IB Actions **/
    
    @IBAction func addFrame(_ sender: NSButton) {
        
        guard currentDocument != nil else { return }
        
        var currentTime: String = "00:00"
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = true
        imgBrowsePanel.canChooseDirectories = false
        // A JPG document accepts a frame saved with either spelling; it is written back below
        // under the document's own extension.
        imgBrowsePanel.allowedFileTypes = fileType! == FileExtensions.JPG ? [FileExtensions.JPG, FileExtensions.JPEG] : [fileType!]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if result == NSApplication.ModalResponse.OK {
                
                guard let index = self.currentDocument?.currentPageIndex.first else { return }
                
                let currentPage = self.currentDocument!.getXmlObjPages()[index]
                
                for (index, url) in imgBrowsePanel.urls.enumerated() {
                    
                    let fileName = self.currentDocument!.getFileNamePrefix() +  Util.shared.formatPageNum(num: currentPage.number + 1) + "-" + String(self.frameTable.numberOfRows + 1 + index) + "." + self.fileType!
                    
                    self.currentDocument!.addAssetsWrappersFile(name: fileName, path: url, to: FileNames.PAGES_DIR)
                    
                    do {
                        self.fileContents.append(try Data(contentsOf: url))
                    } catch let error as NSError {
                        NSLog(error.localizedDescription)
                    }
                    
                    if self.audioPlayer != nil {
                        
                        self.audioPlayer!.pause()
                        currentTime = Util.shared.timeAsString(timeInterval: self.audioPlayer!.currentTime)
                        
                    }
                    
                    if currentPage.frames.contains(currentTime) {
                        
                        if let last = currentPage.frames.last {
                            currentTime = Util.shared.timeAsString(timeInterval: Util.shared.timeStringToSeconds(time: last) + 1.0 )
                        } else {
                            currentTime = "00:00"
                        }
                        
                    }
                    
                    currentPage.addFrame(frame: currentTime)
                    
                }
                
                self.reloadFrameTable()
                self.frameTable.selectRowIndexes([self.frameTable.numberOfRows - 1], byExtendingSelection: false)
                self.currentDocument!.updateChangeCount(.changeDone)
                
            }
            
        } )
        
    }
    
    @IBAction func deleteFrame(_ sender: NSButton) {
        
        guard currentDocument != nil else { return }
        guard let index = currentDocument?.currentPageIndex.first else { return }
        
        // Frame 1 is the 00:00 frame the player opens on, and the parser puts it back whatever is
        // stored, so it is never removed — a selection that takes it in simply keeps it.
        let doomed = frameTable.selectedRowIndexes.filter({ $0 > 0 && $0 < frames.count })
        
        guard !doomed.isEmpty else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        let src = currentPage.src
        let existingCount = frames.count
        
        // Every surviving image is read out first, then every old name is cleared, then they go back
        // as one contiguous run. Renaming in place instead would have two frames wanting the same
        // name partway through, since everything below a deleted frame shifts up.
        var survivors: Array<FileWrapper?> = []
        
        for i in 0..<existingCount where !doomed.contains(i) {
            survivors.append(currentDocument!.getAssetFileWrapper(name: "\(src)-\(i + 1).\(fileType!)", at: FileNames.PAGES_DIR))
        }
        
        for i in 0..<existingCount {
            
            currentDocument!.removeFileFromAssetsDir(file: "\(src)-\(i + 1).\(fileType!)", subDir: FileNames.PAGES_DIR)
            // The "~" copies hold the bytes a slide is renamed from when it moves in the outline, and
            // one is only made if it isn't there already — a leftover still holding the pre-delete
            // image would quietly put the deleted frames back the next time this slide is reordered.
            currentDocument!.removeFileFromAssetsDir(file: "~\(src)-\(i + 1).\(fileType!)", subDir: FileNames.PAGES_DIR)
            
        }
        
        // A frame whose image was already missing keeps its gap rather than pulling the images below
        // it up a row; setImageData() stands an empty placeholder in for it either way.
        for (position, file) in survivors.enumerated() {
            
            guard let file = file else { continue }
            currentDocument!.addAssetsWrappersFile(name: "\(src)-\(position + 1).\(fileType!)", file: file, to: FileNames.PAGES_DIR)
            
        }
        
        // Held across the whole rebuild, not just the final selection: reloadData() can have AppKit
        // adjust the selection itself as rows appear or disappear under it, and that lands here as a
        // selection change like any other. Selecting a row normally means "take me to that point in
        // the narration", but none of this was a request to move the playhead.
        shouldScrub = false
        
        for i in doomed.sorted(by: >) {
            currentPage.frames.remove(at: i)
        }
        
        reloadFrameTable()
        setImageData()
        
        // Land on the frame above the first one removed, the way a list behaves after a delete.
        let selection = max(0, doomed.min()! - 1)
        
        frameTable.selectRowIndexes([selection], byExtendingSelection: false)
        shouldScrub = true
        
        displayImage(index: selection)
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    @IBAction func onAudioScrub(_ sender: NSSlider) {
        
        if audioPlayer != nil {
            audioPlayer!.currentTime = sender.doubleValue
            currentTime.stringValue = Util.shared.timeAsString(timeInterval: sender.doubleValue)
            currentFrameIndex = -1
            showCaption(at: sender.doubleValue)
            
            // Inside the nil check that guards the rest of the method: there is nothing to scrub,
            // and nothing to update the view from, when no narration is loaded.
            if audioPlayer!.isPlaying == false {
                updateView()
            }
            
        }
        
    }
    
    @IBAction func playPauseAudio(_ sender: NSButton) {
        
        if (audioPlayer!.isPlaying) {
            
            audioPlayer?.pause()
            sender.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
            updateView()
            timer?.invalidate()
            
            audioPlayerBox.alphaValue = 1
            
            if audioBoxTimer != nil {
                audioBoxTimer!.invalidate()
            }
            
        } else {
            
            audioPlayer?.play()
            sender.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause")
            startTimer()
            
        }
        
    }
    
    @IBAction func frameTimeChange(_ sender: NSTextField) {
        
        guard currentDocument != nil else { return }
        guard let index = currentDocument?.currentPageIndex.first else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        // The row this field belongs to, not the selected one: with several rows selected the
        // selection's own row is whichever was picked last, which is not necessarily this one.
        let row = frameTable.row(for: sender.superview!)
        
        guard row >= 0 && row < currentPage.frames.count else { return }
        
        if sender.stringValue.range(of: "^([0-9]{2}:)?([0-9]{2}:[0-9]{2,})$", options: .regularExpression) == nil {
            Util.shared.showAlert(message: "Incorrect Timecode Format!", informative: "Please enter the timecode in the either one of the following formats: 00:00 or 00:00:00.", style: .critical)
            sender.stringValue = currentPage.frames[row]
            return
        }
        
        let sanitizedTime = Util.shared.sanitizeTime(timecode: sender.stringValue)
        
        if currentPage.frames[row] != sanitizedTime {
            
            if !currentPage.frames.contains(sanitizedTime) {
                
                currentPage.frames[row] = sanitizedTime
                sender.stringValue = sanitizedTime
                frames = currentPage.frames
                currentDocument!.updateChangeCount(.changeDone)
                
            } else {
                
                sender.stringValue = currentPage.frames[row]
                Util.shared.showAlert(message: "Time Conflict!", informative: "A frame already specified at that time. Please try a different time.", style: .critical)
                
            }
            
        }
        
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
    
    @IBAction func updateFrameImg(_ sender: NSButton) {
        
        guard let index = currentDocument?.currentPageIndex.first else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        let row = frameTable.row(for: sender.superview!)
        
        frameTable.selectRowIndexes([row], byExtendingSelection: false)
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = false
        imgBrowsePanel.canChooseDirectories = false
        // A JPG document accepts a frame saved with either spelling; it is written back below
        // under the document's own extension.
        imgBrowsePanel.allowedFileTypes = fileType! == FileExtensions.JPG ? [FileExtensions.JPG, FileExtensions.JPEG] : [fileType!]
        
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
        
        // Rebuilt from scratch every time: this used to run once per load, but a dropped frame runs
        // it again, and appending to what was already there would leave the preview reading the
        // image data of the frame that used to be at that row.
        files = []
        fileContents = []
        
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
        
        // The loop above stands an empty wrapper in for a frame whose image is missing, and an empty
        // wrapper has no contents at all. displayImage() already skips a zero-length entry.
        files.forEach({fileContents.append($0.regularFileContents ?? Data())})
    
    }
    
    private func displayImage(index: Int) {
        
        if !fileContents.isEmpty {
           
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
        // A quarter-second tick: at half a second a caption visibly trails the narration,
        // which is the one thing this display exists to let someone check.
        timer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(self.updateViewWithTimer), userInfo: nil, repeats: true)
    }
    
    @objc func updateViewWithTimer(timer: Timer) {
        updateView()
    }
    
    private func updateView() {
        
        currentTime.stringValue = Util.shared.timeAsString(timeInterval: audioPlayer!.currentTime)
        audioSlider.doubleValue = audioPlayer!.currentTime

        showCaption(at: audioPlayer!.currentTime)
        
        let targetIndex = setFrameImage(index: currentFrameIndex, time: audioPlayer!.currentTime)
        
        if currentFrameIndex != targetIndex, targetIndex >= 0 {
            
            currentFrameIndex = targetIndex
            
            // The list follows the narration, but not at the cost of a selection someone is still
            // building: seeking, pausing, or simply crossing a frame boundary would otherwise throw
            // away a multi-row selection made for a bulk delete. The preview follows either way.
            if frameTable.selectedRowIndexes.count <= 1 {
                
                // Suppressed up front rather than announced afterwards: this selection is the
                // narration reporting where it has reached, not a request to seek to it, and the
                // change is delivered the moment the row is selected.
                shouldScrub = false
                frameTable.selectRowIndexes([currentFrameIndex], byExtendingSelection: false)
                shouldScrub = true
                
            }
            
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
        
        // No frames at all: there is no index to land on, and answering 0 would have the caller
        // select row 0 of an empty table, which raises rather than returning.
        guard !frames.isEmpty else { return -1 }

        // A negative index is the caller asking for a search from scratch — it is what scrubbing
        // sets, having no idea which frame the new position lands in — so the walk starts at the
        // first frame and goes forward from there. Answering 0 outright instead, as this did, made
        // every scrub land on frame 1 no matter where the playhead went.
        //
        // What stops the infinite recursion that answering 0 was reaching for is the "time <
        // frameTime" case below refusing to step back past the first frame: from 0 the walk can
        // only end at 0 or move forward, so it cannot turn around and come back here.
        if index < 0 {
            return setFrameImage(index: 0, time: time)
        }
        
        if frames.index(after: index) >= frames.count {
            return frames.count - 1
        }
        
        let frameTime = Util.shared.timeStringToSeconds(time: frames[index])
        let nextFrameTime = Util.shared.timeStringToSeconds(time: frames[frames.index(after: index)])
        
        if time < frameTime {

            // Still before the first frame's own time: this is as far back as it goes.
            guard index > 0 else { return 0 }

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
        audioPlayBtn.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
        timer?.invalidate()
        
        if frameTable.selectedRowIndexes.count <= 1 {
            
            shouldScrub = false
            frameTable.selectRowIndexes([0], byExtendingSelection: false)
            shouldScrub = true
            
        }
        
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
    

    // The cues are drawn here rather than played through the audio player, which has no notion of a
    // caption track at all. The bar hangs above the floating transport controls so it reads as
    // sitting under the slide image, where a viewer of the finished presentation would see it.
    private func showCaption(at time: TimeInterval) {

        guard let captions = captions else { return }

        if captionOverlay == nil {
            captionOverlay = CaptionOverlayView.install(in: view, above: audioPlayerBox)
        }

        captionOverlay?.show(captions.text(at: time))

    }

}
