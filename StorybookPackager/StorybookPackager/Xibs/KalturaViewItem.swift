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

class KalturaViewItem: NSCollectionViewItem, NSTextViewDelegate, NSTextFieldDelegate {
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var entryIdTxtfld: NSTextField!
    @IBOutlet weak var videoPlayer: AVPlayerView!
    @IBOutlet weak var typeBtn: NSPopUpButton!
    @IBOutlet weak var transitionBtn: NSPopUpButton!
    @IBOutlet weak var notesTxtvw: NSTextView!
    @IBOutlet weak var pageNumLbl: NSTextField!
    
    var document: Document?
    private var currentPageObj: Page?
    private let kPartnerId = UserDefaults.standard.string(forKey: Preferences.KALTURA_PARTNER_ID)!
    private let flavorId = UserDefaults.standard.string(forKey: Preferences.KALTURA_FLAVOR_ID)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        notesTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        
        notesTxtvw.delegate = self
        titleTxtfld.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: videoPlayer.player?.currentItem)
        
    }
    
    override func viewWillAppear() {
        
        super.viewWillAppear()
        
        //document = (NSDocumentController.shared.currentDocument as? Document)!
        currentPageObj = document!.getXmlObjPages()[document!.currentPageIndex.first!]
        
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(currentPageObj!.title)"
        titleTxtfld.stringValue = currentPageObj!.title
        entryIdTxtfld.stringValue = currentPageObj!.src
        notesTxtvw.string = currentPageObj!.notes
        
        typeBtn.selectItem(at: Util.shared.getPageTypeIndex(type: currentPageObj!.type, collection: typeBtn.itemTitles))
        
        guard let url = URL(string: "https://cdnapisec.kaltura.com/p/\(kPartnerId)/sp/0/playManifest/entryId/\(entryIdTxtfld.stringValue)/format/applehttp/protocol/https/flavorParamId/\(flavorId)/video.mp4") else { return }
        
        let avAsset = AVURLAsset(url: url, options: nil)
        let playerItem = AVPlayerItem(asset: avAsset)
        let player = AVPlayer(playerItem: playerItem)

        videoPlayer.player = player
        
    }
    
    func controlTextDidChange(_ obj: Notification) {
        
        guard let tf = (obj.object as? NSTextField) else { return }
        
        pageNumLbl.stringValue = "Page \(currentPageObj!.number + 1): \(tf.stringValue)"
        
        currentPageObj?.title = tf.stringValue
        document!.updateChangeCount(.changeDone)
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: document!)
        
    }
    
    @IBAction func entryIdChange(_ sender: NSTextField) {
        
        if (sender.stringValue != currentPageObj!.src) {
            
            guard let url = URL(string: "https://cdnapisec.kaltura.com/p/\(kPartnerId)/sp/0/playManifest/entryId/\(sender.stringValue)/format/applehttp/protocol/https/flavorParamId/\(flavorId)/video.mp4") else { return }
            
            let avAsset = AVURLAsset(url: url, options: nil)
            let playerItem = AVPlayerItem(asset: avAsset)

            videoPlayer.player?.replaceCurrentItem(with: playerItem)
            
            currentPageObj?.src = sender.stringValue
            document!.updateChangeCount(.changeDone)

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
        
        guard type != self.currentPageObj!.type else { return }
        
        self.currentPageObj!.type = type
        document!.updateChangeCount(.changeDone)
        
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: document!)
        NotificationCenter.default.post(name: Notification.Name("pageSelected"), object: document!)
        
    }
    
}
