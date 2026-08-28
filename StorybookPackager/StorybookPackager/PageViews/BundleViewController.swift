//
//  BundleViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/18/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
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
    /// The frames table and its buttons. PageViewController moves this out to sit beside the notes;
    /// everything on it stays wired to this controller.
    @IBOutlet weak var framesPanel: NSStackView!
    /// The slide itself — image, SVG, and the audio transport. Captions belong over this, not over
    /// the whole view, which used to include the frames panel and pulled the caption bar off-centre.
    @IBOutlet weak var contentBox: NSBox!
    @IBOutlet weak var frameTable: NSTableView!
    @IBOutlet weak var addFrameBtn: NSButton!
    @IBOutlet weak var deleteFrameBtn: NSButton!
    @IBOutlet weak var updateFrameTimeBtn: NSButton!
    @IBOutlet weak var replaceFrameImgBtn: NSButton!
    
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
    /// Set by PageViewController, which owns the Pin Controls checkbox in the Sources row — the
    /// transport it pins belongs to this slide, but the checkbox sits with the other page controls.
    var controlsPinned: Bool = true
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

        // Each of the four frame buttons carries a symbol and, if the symbol is unavailable, the
        // short title it was given in the storyboard — the same fallback the Title Case and OCR
        // buttons above the slide use.
        symbolOrTitle(addFrameBtn, symbol: "plus", describing: "Add frame")
        symbolOrTitle(deleteFrameBtn, symbol: "minus", describing: "Delete frame")
        symbolOrTitle(updateFrameTimeBtn, symbol: "arrow.up.circle.fill", describing: "Set frame time")
        symbolOrTitle(replaceFrameImgBtn, symbol: "photo.fill", describing: "Replace frame image")

        // The list has one column and a heading of its own above it, so the table's own header is a
        // blank band across the top. Hiding it in the storyboard still reserves its height; taking
        // the header view away is what removes it.
        frameTable.headerView = nil

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
    
    private func symbolOrTitle(_ button: NSButton, symbol: String, describing description: String) {

        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description) {
            button.image = image
        } else {
            button.imagePosition = .noImage
        }

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
            
        }
        
        // A bundle with no name yet stays without one. Merely opening an empty bundle used to claim
        // a name — one built from the slide's position, so on a slide inserted since the last save it
        // was the name its neighbour's frames were still filed under — and claimed it without marking
        // the document changed. The name is taken where the first frame goes in, in insertFrames.
        
        reloadFrameTable()
        setImageData()
        displayImage(index: 0) // display the first frame image
        updateFrameButtonStates()
        
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
                
                // Restored as well as taken away: these cells are recycled, so a cell that was once
                // row 0 keeps row 0's locked timecode when it comes back as another row — which the
                // rows shifting up after a delete makes easy to hit.
                cell.textField?.isEditable = row != 0
                
                if row <= frames.count - 1 {
                    // Shown in full so the column reads straight down; what is stored stays compact.
                    cell.textField?.stringValue = Util.shared.fullTimecode(from: frames[row])
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
        
        updateFrameButtonStates()

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
        
        // Always an insertion, and the top of the list is a legitimate place to land: images dropped
        // there take over the start of the slide and push the frame that was first back a second.
        tableView.setDropRow(min(max(row, 0), frames.count), dropOperation: .above)
        
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
        
        // Squared up here as well as in the shared insert: the row and the times are both worked out
        // from this list before the insert ever sees them, and they have to describe the same one.
        if let index = currentDocument?.currentPageIndex.first {
            frames = currentDocument!.getXmlObjPages()[index].frames
        }
        
        // Finder hands the files over in its own order, and a plain sort reads "img10" as coming
        // before "img2" — the numbering in the names is what the author means by the sequence.
        let sorted = urls.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })
        // AppKit hands back the row validateDrop set, but an index that fell outside the list
        // would trap rather than misbehave, so it is pinned to the list either way.
        let insertIndex = min(max(row, 0), frames.count)
        
        guard let times = newFrameTimes(count: sorted.count, insertingAt: insertIndex) else { return false }
        
        return insertFrames(from: sorted, at: insertIndex, times: times)
        
    }
    
    // The one place frames are added. Both the + button and a drop on the list come through here, so
    // the list stays ascending and the images stay a contiguous run whichever way they arrived.
    @discardableResult
    private func insertFrames(from sorted: Array<URL>, at insertIndex: Int, times: Array<String>) -> Bool {
        
        guard currentDocument != nil else { return false }
        guard let index = currentDocument?.currentPageIndex.first else { return false }
        guard !sorted.isEmpty, times.count == sorted.count else { return false }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        
        // The page is the truth; this cache is only refreshed when a slide is loaded. An outline
        // edit can rebuild the pages underneath an open editor — and the parser puts a 00:00 frame
        // back on a slide left with none — so the two are squared up before anything is read, and
        // the caller's index is checked against the squared-up list rather than the stale one.
        let expected = frames.count
        
        frames = currentPage.frames
        
        // Moved underneath the caller between allocating the times and applying them: those times
        // describe a list that no longer exists, so the safe thing is to redraw and drop the insert.
        guard expected == frames.count else {
            reloadFrameTable()
            return false
        }
        
        guard insertIndex >= 0 && insertIndex <= frames.count else { return false }
        
        // Going in at the top only makes sense for a run that starts the slide at 00:00, and the
        // rewrite below is only sound for one. That is a property of the allocator, not of the
        // index, so it is checked here — a future allocator cannot quietly reintroduce the phantom
        // frame this whole arrangement exists to prevent.
        guard insertIndex > 0 || frames.isEmpty || times.first == "00:00" else { return false }
        
        let displacesFirst = insertIndex == 0 && !frames.isEmpty
        let existingCount = frames.count
        
        // Frames are the first files a bundle holds, so this is where it takes its name — reserved
        // free across every slot a slide can occupy, counting the frames about to go in as well as
        // the ones already there, since neither is in page.frames yet.
        let src = currentDocument!.assetBaseName(for: currentPage, frameCount: existingCount + sorted.count)
        
        currentPage.src = src
        
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
        // one is only made if it isn't there already. A leftover holds the pre-renumbering image and
        // would quietly put the old images back the next time this slide is reordered — so they go
        // now and get made fresh when they are next needed.
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
        
        // Inserted in front of everything, so the frame that used to open the slide no longer does:
        // it takes the second after the new run, which the time allocation left free for it. Leaving
        // it on 00:00 would put two frames there, and the parser strips a leading 00:00 on write.
        if displacesFirst {
            
            // A second later where the gap allows it, and the middle of what's left where it does
            // not — worked out from the frame it has to stay in front of rather than assumed, so it
            // holds however the run above it was spaced.
            let last = seconds(of: times.last!)
            let following = frames.count > 1 ? seconds(of: frames[1]) : last + 2
            let displaced = last + 1 < following ? last + 1 : rounded((last + following) / 2)
            
            currentPage.frames[times.count] = Util.shared.preciseTimeAsString(timeInterval: displaced)
            
        }
        
        reloadFrameTable()
        setImageData()
        
        frameTable.selectRowIndexes([insertIndex], byExtendingSelection: false)
        shouldScrub = true
        
        displayImage(index: insertIndex)
        currentDocument!.updateChangeCount(.changeDone)
        
        return true
        
    }
    
    // Whether a frame may take a given time, and in plain words why not when it may not. The list
    // has to stay unique and ascending: the player and the preview both walk it in order, and the
    // frame at the top holds 00:00 because something has to be on screen when the narration starts.
    private func retimingRefusal(row: Int, to time: String) -> String? {
        
        guard row >= 0 && row < frames.count else { return "That frame is no longer there." }
        guard row > 0 else { return "The first frame opens the slide, so it always starts at 00:00." }
        
        if frames[row] == time { return nil }
        
        if frames.contains(time) {
            return "A frame already starts at \(time). Two frames can't start at the same moment."
        }
        
        let wanted = seconds(of: time)
        
        if wanted < seconds(of: frames[row - 1]) + Self.MIN_FRAME_GAP {
            return "Frame \(row + 1) has to start after frame \(row), at \(frames[row - 1]). Frames run in the order they play."
        }
        
        if row + 1 < frames.count, wanted > seconds(of: frames[row + 1]) - Self.MIN_FRAME_GAP {
            return "Frame \(row + 1) has to start before frame \(row + 2), at \(frames[row + 1]). Frames run in the order they play."
        }
        
        return nil
        
    }
    
    // The closest two frames may sit: a hundredth, the resolution a timecode is written to.
    private static let MIN_FRAME_GAP: Double = 0.01
    
    private func seconds(of time: String) -> Double {
        return Util.shared.timeStringToSeconds(time: time)
    }
    
    private func rounded(_ seconds: Double) -> Double {
        return (seconds * 100).rounded() / 100
    }
    
    // `slots` times spread evenly through the open gap between `after` and `before`, for when whole
    // seconds won't fit. Rounded to hundredths and forced to keep rising, so two frames can never
    // round onto the same moment. Nil when even hundredths apart won't fit.
    private func subdivide(_ slots: Int, after: Double, before: Double) -> Array<Double>? {
        
        guard slots > 0 else { return nil }
        guard before - after >= Double(slots + 1) * Self.MIN_FRAME_GAP else { return nil }
        
        let step = (before - after) / Double(slots + 1)
        var spread: Array<Double> = []
        var last = after
        
        for n in 1...slots {
            
            var moment = rounded(after + step * Double(n))
            
            if moment <= last {
                moment = rounded(last + Self.MIN_FRAME_GAP)
            }
            
            spread.append(moment)
            last = moment
            
        }
        
        guard let final = spread.last, final < before else { return nil }
        
        return spread
        
    }
    
    // Where a run of `count` frames asked for at `moment` belongs, and the times it takes. The frame
    // that opens the slide holds 00:00, so a frame asked for at the very start goes after it. The
    // first of the run lands on the moment itself — the playhead is the whole point of the + button,
    // and it is no longer rounded to the nearest second on the way in.
    private func framesFollowing(moment: Double, count: Int) -> (Int, Array<String>)? {
        
        guard count > 0 else { return nil }
        
        guard !frames.isEmpty else {
            return (0, (0..<count).map({ Util.shared.preciseTimeAsString(timeInterval: TimeInterval($0)) }))
        }
        
        var start = rounded(max(moment, Self.MIN_FRAME_GAP))
        
        // Never on top of a frame that is already there: nudged past one it lands on.
        while let clash = frames.first(where: { abs(seconds(of: $0) - start) < Self.MIN_FRAME_GAP }) {
            start = rounded(seconds(of: clash) + Self.MIN_FRAME_GAP)
        }
        
        let insertIndex = frames.filter({ seconds(of: $0) < start }).count
        let following = insertIndex < frames.count ? seconds(of: frames[insertIndex]) : Double.greatestFiniteMagnitude
        
        // A second apart while that fits before the next frame, and a share of what is left when it
        // doesn't. Only a gap too small to hold them a hundredth apart is refused.
        if start + Double(count - 1) < following {
            return (insertIndex, (0..<count).map({ Util.shared.preciseTimeAsString(timeInterval: start + TimeInterval($0)) }))
        }
        
        guard let spread = subdivide(count - 1, after: start, before: following) else {
            
            let informative = "There isn't room between \(Util.shared.preciseTimeAsString(timeInterval: start)) and \(frames[insertIndex]) for \(count) image\(count == 1 ? "" : "s"). Move the playhead somewhere with more room, move the following frame later, or add fewer images."
            
            DispatchQueue.main.async {
                Util.shared.showAlert(message: "Not Enough Room!", informative: informative, style: .critical)
            }
            
            return nil
            
        }
        
        return (insertIndex, ([start] + spread).map({ Util.shared.preciseTimeAsString(timeInterval: $0) }))
        
    }
    
    // Timecodes for `count` frames landing at `insertIndex`, or nil when the gap they land in has no
    // room to give each one a moment of its own — frame times have to stay unique and ascending, so
    // a gap too tight even for hundredths is refused rather than half-filled.
    private func newFrameTimes(count: Int, insertingAt insertIndex: Int) -> Array<String>? {
        
        guard count > 0 else { return nil }
        
        if insertIndex == 0 {
            
            let wholeSeconds = (0..<count).map({ Util.shared.preciseTimeAsString(timeInterval: TimeInterval($0)) })
            
            guard !frames.isEmpty else { return wholeSeconds }
            
            // Going in front of everything, the run starts the slide at 00:00 and the frame that was
            // first is pushed back — so it needs a slot of its own after the run, and the whole lot
            // still has to land before whatever followed it.
            let following = frames.count > 1 ? seconds(of: frames[1]) : Double.greatestFiniteMagnitude
            
            if Double(count) < following {
                return wholeSeconds
            }
            
            // The run has to keep its 00:00 — it is what opens the slide — so only the frames after
            // the first share out the gap, and one slot is held back for the frame being displaced.
            guard let spread = subdivide(count, after: 0, before: following) else {
                
                let informative = "There isn't room before \(frames[1]) for \(count) image\(count == 1 ? "" : "s") and the frame they push back. Move that frame later, or drop fewer images."
                
                DispatchQueue.main.async {
                    Util.shared.showAlert(message: "Not Enough Room!", informative: informative, style: .critical)
                }
                
                return nil
                
            }
            
            return ([0] + spread.dropLast()).map({ Util.shared.preciseTimeAsString(timeInterval: $0) })
            
        }
        
        let prev = seconds(of: frames[insertIndex - 1])
        
        // Dropped at the end there is nothing to fit between, so the frames simply follow on a
        // second apart. The narration's length is not checked here, and the + button doesn't either.
        if insertIndex == frames.count {
            return (1...count).map({ Util.shared.preciseTimeAsString(timeInterval: prev + TimeInterval($0)) })
        }
        
        let next = seconds(of: frames[insertIndex])
        
        // Whole seconds while the gap has room for them, so an ordinary drop still reads in round
        // numbers, and a share of the gap when it hasn't — which is what a hundredth of a second of
        // resolution buys: a tight gap no longer refuses the drop outright.
        if next - prev - 1 >= Double(count) {
            
            var times: Array<String> = []
            var last = prev
            
            for n in 1...count {
                
                // Spread across the gap, then held to a second past the frame before it and far
                // enough ahead of the next to leave room for the ones still to be placed. The gap
                // was checked above, so those two bounds cannot cross.
                var second = prev + (Double(next - prev) * Double(n) / Double(count + 1)).rounded()
                
                second = max(second, last + 1)
                second = min(second, next - 1 - Double(count - n))
                
                times.append(Util.shared.preciseTimeAsString(timeInterval: second))
                last = second
                
            }
            
            return times
            
        }
        
        guard let spread = subdivide(count, after: prev, before: next) else {
            
            // Off the drop's call stack: this runs while the drag session is still unwinding, and
            // an app-modal alert raised from there holds the drag source — Finder, usually — until
            // someone dismisses it. The drop itself still fails immediately.
            let informative = "There isn't room between \(frames[insertIndex - 1]) and \(frames[insertIndex]) for \(count) image\(count == 1 ? "" : "s"). Move the following frame later, or drop fewer images."
            
            DispatchQueue.main.async {
                Util.shared.showAlert(message: "Not Enough Room!", informative: informative, style: .critical)
            }
            
            return nil
            
        }
        
        return spread.map({ Util.shared.preciseTimeAsString(timeInterval: $0) })
        
    }
    
    /** IB Actions **/
    
    @IBAction func addFrame(_ sender: NSButton) {
        
        guard currentDocument != nil else { return }
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = true
        imgBrowsePanel.canChooseDirectories = false
        // A JPG document accepts a frame saved with either spelling; it is written back below
        // under the document's own extension.
        imgBrowsePanel.allowedFileTypes = fileType! == FileExtensions.JPG ? [FileExtensions.JPG, FileExtensions.JPEG] : [fileType!]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            guard result == NSApplication.ModalResponse.OK, !imgBrowsePanel.urls.isEmpty else { return }
            
            self.audioPlayer?.pause()
            
            if let index = self.currentDocument?.currentPageIndex.first {
                self.frames = self.currentDocument!.getXmlObjPages()[index].frames
            }
            
            // The playhead is where the author is asking for the frame, so the frame goes where that
            // time belongs in the list — not on the end. Appending regardless, as this did, left the
            // times out of order the moment the playhead sat before the last frame, and both the
            // player and the preview walk the list expecting it to ascend.
            let playhead = self.audioPlayer?.currentTime ?? 0
            let sorted = imgBrowsePanel.urls.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })
            
            guard let (insertIndex, times) = self.framesFollowing(moment: playhead, count: sorted.count) else { return }
            
            self.insertFrames(from: sorted, at: insertIndex, times: times)
            
        } )
        
    }
    
    @IBAction func deleteFrame(_ sender: NSButton) {
        
        guard currentDocument != nil else { return }
        guard let index = currentDocument?.currentPageIndex.first else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        
        // As in insertFrames: the page's own list is the truth, and it can move underneath an open
        // editor when the outline is rebuilt. Rows that fall outside it drop out of the selection
        // below; the table is reloaded once at the end rather than under its own selection here.
        frames = currentPage.frames
        
        let doomed = frameTable.selectedRowIndexes.filter({ $0 >= 0 && $0 < frames.count })
        
        guard !doomed.isEmpty else {
            reloadFrameTable()
            return
        }
        
        // Deleting frames cannot be undone — nothing in a page's contents can be, and the images go
        // out of the package with them. A single frame goes without ceremony, as it always has, but
        // taking out a run of them (⌘A on this list is one keystroke) is worth a question first.
        if doomed.count > 1 {
            
            let alert = NSAlert()
            alert.messageText = doomed.count == frames.count ? "Delete all \(doomed.count) frames?" : "Delete \(doomed.count) frames?"
            alert.informativeText = doomed.count == frames.count ? "The slide will be left with its narration and no images. This can't be undone." : "Their images are removed from the presentation. This can't be undone."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            
            guard alert.runModal() == .alertFirstButtonReturn else {
                reloadFrameTable()
                return
            }
            
        }
        
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
        
        // Something has to be on screen when the narration starts, so whatever is left at the top
        // takes over 00:00 — the image that followed the deleted one now opens the slide. This is
        // not cosmetic: the parser synthesises a leading 00:00 on load and drops it on write, so a
        // first frame timed at anything else comes back with an extra frame and every image shifted
        // one place along. The times are unique and ascending, so nothing else can hold 00:00.
        if let first = currentPage.frames.first, first != "00:00" {
            currentPage.frames[0] = "00:00"
        }
        
        reloadFrameTable()
        setImageData()
        
        // Land on the frame above the first one removed, the way a list behaves after a delete.
        let selection = max(0, doomed.min()! - 1)
        
        if frames.isEmpty {
            
            // Nothing left to show. Selecting row 0 of an empty table raises rather than returning,
            // and the preview would otherwise keep displaying the frame that was just deleted.
            imageView.image = nil
            svgImageView.isHidden = true
            currentFrameIndex = -1
            
        } else {
            
            frameTable.selectRowIndexes([selection], byExtendingSelection: false)
            displayImage(index: selection)
            
        }
        
        shouldScrub = true
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
        
        // As in the other mutators: the page's list is the truth, and retimingRefusal reads the
        // cache while the write goes to the page — they have to be the same list or a valid time
        // gets refused, or worse, an invalid one gets through.
        frames = currentPage.frames
        
        // The row this field belongs to, not the selected one: with several rows selected the
        // selection's own row is whichever was picked last, which is not necessarily this one.
        let row = frameTable.row(for: sender.superview!)
        
        guard row >= 0 && row < currentPage.frames.count else { return }
        
        if sender.stringValue.range(of: "^([0-9]{2}:)?([0-9]{2}:[0-9]{2})(\\.[0-9]{1,2})?$", options: .regularExpression) == nil {
            Util.shared.showAlert(message: "Incorrect Timecode Format!", informative: "Please enter the timecode as 00:00 or 00:00:00, with hundredths of a second after a full stop if you need them — 00:04.75.", style: .critical)
            sender.stringValue = Util.shared.fullTimecode(from: currentPage.frames[row])
            return
        }
        
        let sanitizedTime = Util.shared.sanitizeTime(timecode: sender.stringValue)
        
        guard currentPage.frames[row] != sanitizedTime else { return }
        
        if let refusal = retimingRefusal(row: row, to: sanitizedTime) {
            
            sender.stringValue = Util.shared.fullTimecode(from: currentPage.frames[row])
            Util.shared.showAlert(message: "Can't Use That Time", informative: refusal, style: .critical)
            return
            
        }
        
        currentPage.frames[row] = sanitizedTime
        sender.stringValue = Util.shared.fullTimecode(from: sanitizedTime)
        frames = currentPage.frames
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    @IBAction func updateFrameTime(_ sender: NSButton) {
        
        guard let index = currentDocument?.currentPageIndex.first else { return }
        guard let time = audioPlayer?.currentTime else { return }
        
        let currentPage = currentDocument!.getXmlObjPages()[index]
        // The selected frame: this button sits under the list with the others now, rather than on
        // the row it applies to.
        let row = frameTable.selectedRow
        // The moment the narration is actually at, not the second it is nearest — pinning a frame
        // to a word is the reason this button exists.
        let timeAsStr = Util.shared.preciseTimeAsString(timeInterval: time)
        
        frames = currentPage.frames
        
        guard row >= 0 && row < frames.count, timeAsStr != frames[row] else { return }
        
        // Held to the same rule as typing a time in. This checked neither order nor duplicates, so
        // parking the playhead before the previous frame and pressing the button was enough to leave
        // the list unsorted, which is exactly what the player walks in order.
        if let refusal = retimingRefusal(row: row, to: timeAsStr) {
            
            Util.shared.showAlert(message: "Can't Use That Time", informative: refusal, style: .critical)
            return
            
        }
        
        currentPage.frames[row] = timeAsStr
        frames = currentPage.frames
        frameTable.reloadData(forRowIndexes: [row], columnIndexes: [0])
        frameTable.selectRowIndexes([row], byExtendingSelection: false)
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    @IBAction func updateFrameImg(_ sender: NSButton) {
        
        guard currentDocument != nil else { return }
        
        let row = frameTable.selectedRow
        
        guard row >= 0 && row < frames.count else { return }
        
        // The page itself is resolved inside the completion handler, once the sheet is done.
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = false
        imgBrowsePanel.canChooseDirectories = false
        // A JPG document accepts a frame saved with either spelling; it is written back below
        // under the document's own extension.
        imgBrowsePanel.allowedFileTypes = fileType! == FileExtensions.JPG ? [FileExtensions.JPG, FileExtensions.JPEG] : [fileType!]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if result == NSApplication.ModalResponse.OK {
                
                guard self.fileContents.indices.contains(row) else { return }

                // Re-resolved now, not captured before the panel opened: rebuilding the outline
                // replaces every Page with a copy, and writing the reserved name onto a discarded
                // one would leave the live slide nameless and the image swept at the next save.
                guard let liveIndex = self.currentDocument?.currentPageIndex.first,
                      self.currentDocument!.getXmlObjPages().indices.contains(liveIndex) else { return }

                let currentPage = self.currentDocument!.getXmlObjPages()[liveIndex]
                
                // Replacing a frame is one of the ways a bundle first comes to hold a file, so it
                // takes its name here if it hasn't got one. Built straight from src, an unnamed
                // bundle wrote "-1.jpg" — a hidden file the editor then previewed, so it looked as
                // though it had worked, and the next save swept it away without a word.
                let base = self.currentDocument!.assetBaseName(for: currentPage, frameCount: max(currentPage.frames.count, 1))

                currentPage.src = base

                let fileName = "\(base)-\(row + 1).\(self.fileType!)"
                
                // The "~" copy holds the bytes this slide is renamed from when it moves in the
                // outline, and is only made if one isn't there already. Left in place, a shadow from
                // a bulk import would hand back the image this is replacing the next time the slide
                // is reordered, and the replacement would look as though it never happened.
                self.currentDocument!.removeFileFromAssetsDir(file: "~" + fileName, subDir: FileNames.PAGES_DIR)
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
    
    func setControlsPinned(_ pinned: Bool) {
        
        controlsPinned = pinned
        
        if pinned {
            fadeAudioBoxIn()
        } else {
            setFadeAudioBoxOut()
        }
        
    }
    
    @objc func mouseOver(_ sender: Notification) {
        
        guard (sender.object as? NSWindow) == self.view.window else { return }
        
        if !controlsPinned {
        
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
        
        if !controlsPinned {
            
            if audioPlayer != nil && audioPlayer!.isPlaying {
                setFadeAudioBoxOut()
            }
            
        }
        
    }
    
    // The three buttons under the list all act on the selection, so they follow it. Replacing an
    // image and setting a time apply to one frame, so they wait for exactly one to be picked; the
    // first frame's time is always 00:00, and there is nothing to set a time from without narration.
    private func updateFrameButtonStates() {
        
        let selection = frameTable.selectedRowIndexes
        let single = selection.count == 1 ? selection.first : nil
        
        deleteFrameBtn.isEnabled = !selection.isEmpty
        replaceFrameImgBtn.isEnabled = single != nil
        updateFrameTimeBtn.isEnabled = single != nil && single! > 0 && audioPlayer != nil
        
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
            
            // A bundle with no name of its own owns no frame images. Built from an empty base this
            // read "-1.jpg", which is a real file in a package written by 1.9.9 — so the slide
            // previewed a stray that belonged to no slide at all.
            guard !currentPage.src.isEmpty else {
                return frames.map { _ in FileWrapper() }
            }

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
        
        if fileContents.indices.contains(index) {
           
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
                updateFrameButtonStates()
                
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
        
        // A bundle can now have no frames at all, and selecting row 0 of an empty table raises.
        if !frames.isEmpty && frameTable.selectedRowIndexes.count <= 1 {
            
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
            captionOverlay = CaptionOverlayView.install(in: contentBox.contentView ?? view, above: audioPlayerBox)
        }

        captionOverlay?.show(captions.text(at: time))

    }

}
