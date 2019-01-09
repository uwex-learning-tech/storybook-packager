//
//  PageDetailsViewItem.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/3/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit
import SbXmlParser

class KalturaViewItem: NSCollectionViewItem, NSTextViewDelegate {
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var entryIdTxtfld: NSTextField!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var videoPlayer: AVPlayerView!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var notesTxtvw: NSTextView!
    @IBOutlet weak var pageNumLbl: NSTextField!
    @IBOutlet weak var hiddenPageIndex: NSTextField!
    
    private var doc: Document?
    private var currentPageObj: Page?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        notesTxtvw.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: videoPlayer.player?.currentItem)
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        doc = (NSDocumentController.shared.currentDocument as? Document)!
        currentPageObj = doc!.getXmlObj().getSectionAsPages()[doc!.currentPageIndex.item]
        
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(currentPageObj!.title)"
        
        guard let url = URL(string: "https://cdnapisec.kaltura.com/p/1660872/sp/0/playManifest/entryId/\(entryIdTxtfld.stringValue)/format/applehttp/protocol/https/flavorParamId/487081/video.mp4") else { return }
        
        let avAsset = AVURLAsset(url: url, options: nil)
        let playerItem = AVPlayerItem(asset: avAsset)
        let player = AVPlayer(playerItem: playerItem)
        
        videoPlayer.player = player
        
        typeBtn.selectItem(withTitle: String(self.currentPageObj!.type.capitalized.replacingOccurrences(of: "-", with: " and ")))
        
    }
    
    @IBAction func titleChange(_ sender: NSTextField) {

        if (sender.stringValue != currentPageObj!.title) {
            
            pageNumLbl.stringValue = "Page \(currentPageObj!.number): \(sender.stringValue)"
            
            currentPageObj?.title = sender.stringValue
            doc!.updateChangeCount(.changeDone)
            
            (NSApplication.shared.mainWindow?.contentViewController as? PresentationViewController)!.updatePage()
            
        }
        
    }
    
    @IBAction func entryIdChange(_ sender: NSTextField) {
        
        if (sender.stringValue != currentPageObj!.src) {
            
            guard let url = URL(string: "https://cdnapisec.kaltura.com/p/1660872/sp/0/playManifest/entryId/\(entryIdTxtfld.stringValue)/format/applehttp/protocol/https/flavorParamId/487081/video.mp4") else { return }

            let avAsset = AVURLAsset(url: url, options: nil)
            let playerItem = AVPlayerItem(asset: avAsset)

            videoPlayer.player?.replaceCurrentItem(with: playerItem)
            
            currentPageObj?.src = sender.stringValue
            doc!.updateChangeCount(.changeDone)

        }
        
        
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
