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
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var notesTxtvw: NSTextView!
    @IBOutlet weak var pageNumLbl: NSTextField!
    
    private var doc: Document?
    private var currentPageObj: Page?
    
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
        
        doc = (NSDocumentController.shared.currentDocument as? Document)!
        currentPageObj = doc!.getXmlObjPages()[doc!.currentPageIndex.item]
        
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(currentPageObj!.title)"
        
        if doc!.getAssetsWrapper(name: "\(currentPageObj!.src).mp4", at: "video") != nil {
            
            let directory = "\(NSDocumentController.shared.currentDirectory!)/\(doc!.displayName!)/assets/video/"
            let docBundle = Bundle(path: directory)
            let url = docBundle?.url(forResource: currentPageObj!.src, withExtension: "mp4")
            
            let avAsset: AVAsset = AVAsset(url: url!)
            let playerItem = AVPlayerItem(asset: avAsset)
            let player = AVPlayer(playerItem: playerItem)
            
            videoPlayer.player = player
            
        }
        
    }
    
    func controlTextDidChange(_ obj: Notification) {
        
        guard let tf = (obj.object as? NSTextField) else { return }
        
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(tf.stringValue)"
        
        currentPageObj?.title = tf.stringValue
        doc!.updateChangeCount(.changeDone)
        (NSApplication.shared.mainWindow?.contentViewController as? PresentationViewController)!.refreshCurrentPage()
        
    }
    
    @IBAction func setVideo(_ sender: NSButton) {
        
        self.openBrowsePanel(type: "mp4")
        
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
        let page = doc.getXmlObjPages()[doc.currentPageIndex.item]
        let fileName = url.deletingPathExtension().lastPathComponent
        
        page.src = fileName
        doc.addAssetsWrappersFile(name: "\(fileName).mp4", path: url, to: "video")
        doc.updateChangeCount(.changeDone)
        
    }
    
    @objc func playerDidEnd(_ sender: NSNotification) {
        videoPlayer.player?.seek(to: CMTime.zero)
    }
    
    func textDidEndEditing(_ notification: Notification) {
        
        guard let textView = notification.object as? NSTextView else { return }
        
        if (textView.string != currentPageObj!.notes) {
            currentPageObj?.notes = textView.string
        }
        
    }
    
    @IBAction func pageTypeChange(_ sender: NSPopUpButton) {
        
        let type = Util.shared.formatPageTypeString(string: sender.selectedItem!.title)
        
        self.currentPageObj!.type = type
        doc!.updateChangeCount(.changeDone)
        
        let presentationController = (NSApplication.shared.mainWindow?.contentViewController as? PresentationViewController)!
        
        presentationController.updatePage()
        presentationController.pageDetailsView.reloadData()
        
    }
    
}
