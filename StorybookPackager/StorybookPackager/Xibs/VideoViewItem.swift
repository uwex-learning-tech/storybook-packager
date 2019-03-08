//
//  VideoViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 1/17/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit
import SbXmlParser

class VideoViewItem: NSCollectionViewItem, NSTextViewDelegate, NSTextFieldDelegate {
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var videoPlayer: AVPlayerView!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var notesTxtvw: NSTextView!
    @IBOutlet weak var pageNumLbl: NSTextField!
    
    var document: Document?
    private var currentPageObj: Page?
    private let prefSettings = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        
        notesTxtvw.delegate = self
        titleTxtfld.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: videoPlayer.player?.currentItem)
        NotificationCenter.default.addObserver(self, selector: #selector(self.videoDidSet), name: Notification.Name("didCompleteTask"), object: nil)
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        //document = NSDocumentController.shared.currentDocument as? Document
        currentPageObj = document!.getXmlObjPages()[document!.currentPageIndex.first!]
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(currentPageObj!.title)"
        titleTxtfld.stringValue = currentPageObj!.title
        notesTxtvw.string = currentPageObj!.notes
        typeBtn.selectItem(at: Util.shared.getPageTypeIndex(type: currentPageObj!.type, collection: typeBtn.itemTitles))
        
        if document!.getAssetsWrapper(name: "\(currentPageObj!.src).\(FileExtensions.MP4)", at: "video") != nil {
        
            let videoPath = "\(document!.fileURL!.absoluteString)assets/video/\(currentPageObj!.src).\(FileExtensions.MP4)"
            let videoUrl = URL(string: videoPath)
            
            let avAsset: AVAsset = AVAsset(url: videoUrl!)
            let playerItem = AVPlayerItem(asset: avAsset)
            let player = AVPlayer(playerItem: playerItem)
            
            videoPlayer.player = player
            
        }
        
    }
    
    func controlTextDidChange(_ obj: Notification) {
        
        guard let tf = (obj.object as? NSTextField) else { return }
        
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(tf.stringValue)"
        
        currentPageObj?.title = tf.stringValue
        document!.updateChangeCount(.changeDone)
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: document!)
        
    }
    
    func textDidEndEditing(_ notification: Notification) {
        
        guard let textView = notification.object as? NSTextView else { return }
        
        if (textView.string != currentPageObj!.notes) {
            currentPageObj?.notes = textView.string
        }
        
    }
    
    @IBAction func setVideo(_ sender: NSButton) {
        
        self.openBrowsePanel(type: FileExtensions.MP4)
        
    }
    
    private func openBrowsePanel(type: String) {
        
        let vidBrowsePanel = NSOpenPanel()
        vidBrowsePanel.allowsMultipleSelection = false
        vidBrowsePanel.canChooseDirectories = false
        vidBrowsePanel.allowedFileTypes = [type]
        
        vidBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if (result == NSApplication.ModalResponse.OK) {
                NotificationCenter.default.post(name: Notification.Name("didCompleteTask"), object: vidBrowsePanel.url!)
            }
            
        } )
        
    }
    
    @objc func videoDidSet(_ sender: NSNotification) {
        
        guard let url = sender.object as? URL else { return }
        
        let avAsset = AVURLAsset(url: url, options: nil)
        let playerItem = AVPlayerItem(asset: avAsset)

        self.videoPlayer.player?.replaceCurrentItem(with: playerItem)
        
        let doc = (NSDocumentController.shared.currentDocument as? Document)!
        let page = doc.getXmlObjPages()[doc.currentPageIndex.first!]
        let fileName = prefSettings.string(forKey: Preferences.ASSET_FILE_NAME)! + Util.shared.formatPageNum(num: page.number + 1)
        
        page.src = fileName
        doc.addAssetsWrappersFile(name: "\(fileName).\(FileExtensions.MP4)", path: url, to: FileNames.VIDEO_DIR)
        doc.updateChangeCount(.changeDone)
        
    }
    
    @objc func playerDidEnd(_ sender: NSNotification) {
        videoPlayer.player?.seek(to: CMTime.zero)
    }
    
    @IBAction func pageTypeChange(_ sender: NSPopUpButton) {
        
        let type = Util.shared.formatPageTypeString(string: sender.selectedItem!.title)
        
        guard type != self.currentPageObj!.type else { return }
        
        self.currentPageObj!.type = type
        document!.updateChangeCount(.changeDone)
        
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: document!)
        NotificationCenter.default.post(name: Notification.Name("pageSelected"), object: document!)
        
    }
    
}
