//
//  PageViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/25/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class PageViewController: NSViewController, NSTextFieldDelegate, NSTextViewDelegate {

    @IBOutlet weak var pageHeaderLbl: NSTextField!
    
    @IBOutlet weak var typeTransitionStackView: NSStackView!
    @IBOutlet weak var typePopUpBtn: NSPopUpButton!
    @IBOutlet weak var transitionPopUpBtn: NSPopUpButton!
    @IBOutlet weak var embedHtmlCb: NSButton!
    
    @IBOutlet weak var titleTxtFld: NSTextField!
    @IBOutlet weak var spaceFiller: NSBox!
    
    @IBOutlet weak var videoIdStackView: NSStackView!
    @IBOutlet weak var videoIdTxtFld: NSTextField!
    
    @IBOutlet weak var sourcesStackView: NSStackView!
    @IBOutlet weak var setImageBtn: NSButton!
    @IBOutlet weak var setAudioBtn: NSButton!
    @IBOutlet weak var setVideoBtn: NSButton!
    
    @IBOutlet weak var dynamicContentView: NSView!
    
    @IBOutlet weak var notesWidgetsStackView: NSStackView!
    @IBOutlet weak var notesBtn: NSButton!
    @IBOutlet weak var widgetsBtn: NSButton!
    
    @IBOutlet weak var notesWidgetsContainer: NSView!
    
    var currentDocument: Document?
    private let prefSettings = UserDefaults.standard
    private var notesController: NotesViewController?
    private var widgetsController: WidgetsViewController?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // populate the Transition Pop Up Button with transition names
        // from the Constants class
        transitionPopUpBtn.addItems(withTitles: Transition.NAMES)
        
        // set delegates
        titleTxtFld.delegate = self
        
        // add Notes controller
        if notesController == nil {
            notesController = self.storyboard?.instantiateController(withIdentifier: PageViewIdentifiers.NOTES_VIEW) as? NotesViewController
        }
        
        if notesController != nil {
            addChild(notesController!)
            notesWidgetsContainer.addSubview(notesController!.view)
            notesController!.notesTxtVw.delegate = self
            notesController!.view.isHidden = false
        }
        
        // add Widgets controller
        if widgetsController == nil {
            widgetsController = self.storyboard?.instantiateController(withIdentifier: PageViewIdentifiers.WIDGETS_VIEW) as? WidgetsViewController
        }
        
        if widgetsController != nil {
            addChild(widgetsController!)
            notesWidgetsContainer.addSubview(widgetsController!.view)
            widgetsController!.view.isHidden = true
        }
        
    }
    
    /*** IB ACTIONS ***/
    @IBAction func pageTypeChange(_ sender: NSPopUpButton) {
        
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        let type = Util.shared.formatPageTypeString(string: sender.selectedItem!.title)
        
        guard type != currentPage.type else { return }
        
        currentPage.type = type
        currentDocument!.updateChangeCount(.changeDone)
        setUIs()
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: currentDocument!)

    }
    
    @IBAction func pageTransitionChange(_ sender: NSPopUpButton) {
        
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        let transition = sender.selectedItem!.title
        
        if currentPage.transition != transition && transition != "None" {
            currentPage.transition = transition
            currentDocument!.updateChangeCount(.changeDone)
        }
        
    }
    
    @IBAction func toggleNotesWidgets(_ sender: NSButton) {
        
        guard notesController != nil && widgetsController != nil else { return }
        
        switch sender {
        case widgetsBtn:
            
            // change the state of the button
            notesBtn.state = .off
            widgetsBtn.state = .on
            
            // hide notes view first
            notesController!.view.isHidden = true
            
            // display the widgets view
            widgetsController!.view.isHidden = false
            
            NotificationCenter.default.post(name: Notification.Name("loadWidget"), object: currentDocument!)
        
        case notesBtn:
            
            // change the state of the button
            widgetsBtn.state = .off
            notesBtn.state = .on
            
            // display notes view
            notesController!.view.isHidden = false
            
            // hide widgets view first
            widgetsController!.view.isHidden = true
            
        default:
            break
        }
        
    }
    
    @IBAction func setPageImage(_ sender: NSButton) {
        guard currentDocument != nil else { return }
        openBrowsePanel(type: currentDocument!.getXmlObj().pageImgFormat)
    }
    
    @IBAction func setPageAudio(_ sender: NSButton) {
        self.openBrowsePanel(type: FileExtensions.MP3)
    }
    
    @IBAction func setPageVideo(_ sender: NSButton) {
        self.openBrowsePanel(type: FileExtensions.MP4)
    }
    
    @IBAction func videoIdChange(_ sender: NSTextField) {
        
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        if (sender.stringValue != currentPage.src) {
            
            currentPage.src = sender.stringValue
            setDisplay(forPage: currentPage)
            currentDocument!.updateChangeCount(.changeDone)
            
        }
        
    }
    
    /*** NOTIFICATION METHODS ***/
    
    func controlTextDidChange(_ sender: Notification) {

        guard let tf = (sender.object as? NSTextField) else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        
        if currentPage.type == PageTypes.SECTION {
            pageHeaderLbl.stringValue = "Section \(currentPage.number + 1): \(tf.stringValue)"
        } else {
            pageHeaderLbl.stringValue = "Page \(currentPage.number + 1): \(tf.stringValue)"
        }
        
        currentPage.title = tf.stringValue
        currentDocument!.updateChangeCount(.changeDone)
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: currentDocument!)
        
    }
    
    func textDidEndEditing(_ sender: Notification) {
        
        guard let textView = sender.object as? NSTextView else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        if (textView.string != currentPage.notes) {
            currentPage.notes = textView.string
            currentDocument!.updateChangeCount(.changeDone)
        }
        
    }
    
    /*** HELPER METHODS ***/
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
    }
    
    func setUIs() {
        
        guard currentDocument != nil else { return }
        guard let pageIndex = currentDocument?.currentPageIndex.first else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[pageIndex] else { return }
        
        // set UI display
        setDisplay(forPage: currentPage)

        // set page header title
        if currentPage.type == PageTypes.SECTION {
            
            pageHeaderLbl.stringValue = "Section \(currentPage.number + 1): \(currentPage.title)"
            
            // set page title
            titleTxtFld.stringValue = currentPage.title
            
            return // end function because the rest does not apply
            
        }
        
        /*** if not a section... continues ***/
        
        pageHeaderLbl.stringValue = "Page \(currentPage.number + 1): \(currentPage.title)"
        
        // set the page type
        typePopUpBtn.selectItem(at: Util.shared.getPageTypeIndex(type: currentPage.type, collection: typePopUpBtn.itemTitles))
        
        // set the page transition; set to none if empty
        if !currentPage.transition.isEmpty {
            transitionPopUpBtn.selectItem(withTitle: currentPage.transition)
        } else {
            transitionPopUpBtn.selectItem(at: 0)
        }
        
        // set page title
        titleTxtFld.stringValue = currentPage.title
        
        // set video id
        videoIdTxtFld.stringValue = currentPage.src
        
    }
    
    private func setDisplay(forPage: Page) {

        let pageImgType = currentDocument!.getXmlObj().pageImgFormat
        var childController: NSViewController? = nil
        
        // reset view
        dynamicContentView.constraints[1].constant = 360
        if notesWidgetsContainer.isHidden == false {
            notesWidgetsContainer.frame = NSRect(x: 0, y: 0, width: notesWidgetsStackView.frame.size.width, height: 210)
        }
        self.view.needsLayout = true
        
        for view in dynamicContentView.subviews {
            view.removeFromSuperview()
        }
        
        // get new view
        switch forPage.type {
            
        case PageTypes.SECTION:
            
            typeTransitionStackView.isHidden = true
            spaceFiller.isHidden = false
            embedHtmlCb.isHidden = true
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = true
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = true
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = true
            notesWidgetsStackView.isHidden = true
            
        case PageTypes.IMAGE:
            
            typeTransitionStackView.isHidden = false
            spaceFiller.isHidden = true
            embedHtmlCb.isHidden = true
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = false
            setImageBtn.isHidden = false
            setAudioBtn.isHidden = true
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.IMAGE_VIEW) as! ImageViewController
            dynamicContentView.addSubview(childController!.view)
            (childController as! ImageViewController).fileType = pageImgType
            (childController as! ImageViewController).file = currentDocument!.getAssetFileWrapper(name: "\(forPage.src).\(pageImgType)", at: FileNames.PAGES_DIR)
            (childController as! ImageViewController).setImage()
            
        case PageTypes.IMAGE_AUDIO:
            
            typeTransitionStackView.isHidden = false
            spaceFiller.isHidden = true
            embedHtmlCb.isHidden = true
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = false
            setImageBtn.isHidden = false
            setAudioBtn.isHidden = false
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.IMAGE_AUDIO_VIEW) as! ImageAudioViewController
            addChild(childController!)
            dynamicContentView.addSubview(childController!.view)
            (childController as! ImageAudioViewController).fileType = pageImgType
            (childController as! ImageAudioViewController).file = currentDocument!.getAssetFileWrapper(name: "\(forPage.src).\(pageImgType)", at: FileNames.PAGES_DIR)
            (childController as! ImageAudioViewController).audio = currentDocument!.getAssetFileWrapper(name: "\(forPage.src).\(FileExtensions.MP3)", at: FileNames.AUDIO_DIR)
            (childController as! ImageAudioViewController).setImage()
            
        case PageTypes.BUNDLE:
            
            typeTransitionStackView.isHidden = false
            spaceFiller.isHidden = true
            embedHtmlCb.isHidden = true
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = false
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = false
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            
            notesWidgetsContainer.frame = NSRect(x: 0, y: 0, width: notesWidgetsStackView.frame.size.width, height: 294)
            dynamicContentView.constraints[1].constant = 276
            self.view.needsLayout = true
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.BUNDLE_VIEW) as! BundleViewController
            
            addChild(childController!)
            
            dynamicContentView.addSubview(childController!.view)
            
            (childController as! BundleViewController).fileType = pageImgType
            (childController as! BundleViewController).currentDocument = currentDocument!
            (childController as! BundleViewController).loadBundleFrames()
            
        case PageTypes.QUIZ:
            
            typeTransitionStackView.isHidden = false
            spaceFiller.isHidden = true
            embedHtmlCb.isHidden = true
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = true
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = true
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = true
            
            dynamicContentView.constraints[1].constant = 641
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.QUIZ_VIEW) as! QuizViewController
            addChild(childController!)
            dynamicContentView.addSubview(childController!.view)
            
        case PageTypes.HTML:
            
            typeTransitionStackView.isHidden = false
            spaceFiller.isHidden = true
            embedHtmlCb.isHidden = false
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = false
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = false
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            
        case PageTypes.KALTURA:
            
            typeTransitionStackView.isHidden = false
            spaceFiller.isHidden = true
            embedHtmlCb.isHidden = true
            videoIdStackView.isHidden = false
            sourcesStackView.isHidden = true
            notesWidgetsStackView.isHidden = false
            dynamicContentView.isHidden = false
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.VIDEO_VIEW) as! VideoViewController
            addChild(childController!)
            dynamicContentView.addSubview(childController!.view)
            (childController as! VideoViewController).videoId = forPage.src
            (childController as! VideoViewController).setVideo()
            
        case PageTypes.VIMEO, PageTypes.YOUTUBE:
            
            typeTransitionStackView.isHidden = false
            spaceFiller.isHidden = true
            embedHtmlCb.isHidden = true
            videoIdStackView.isHidden = false
            sourcesStackView.isHidden = true
            notesWidgetsStackView.isHidden = false
            dynamicContentView.isHidden = false
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.STREAMING_VIEW) as! StreamingViewController
            dynamicContentView.addSubview(childController!.view)
            
            if forPage.type == PageTypes.YOUTUBE {
                (childController as! StreamingViewController).youtubeId = forPage.src
            } else {
                (childController as! StreamingViewController).vimeoId = forPage.src
            }
            
            (childController as! StreamingViewController).setVideo()
            
        case PageTypes.VIDEO:
            
            typeTransitionStackView.isHidden = false
            spaceFiller.isHidden = true
            embedHtmlCb.isHidden = true
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = false
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = true
            setVideoBtn.isHidden = false
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.VIDEO_VIEW) as! VideoViewController
            addChild(childController!)
            dynamicContentView.addSubview(childController!.view)
            (childController as! VideoViewController).videoUrl = URL(string: "\(currentDocument!.fileURL!.absoluteString)assets/video/\(forPage.src).\(FileExtensions.MP4)")
            (childController as! VideoViewController).setVideo()
            
        default:
            break
        }
        
        // set notes if applicable
        guard forPage.type != PageTypes.QUIZ && forPage.type != PageTypes.SECTION else { return }
        guard notesController != nil && widgetsController != nil else { return }
        
        if notesController!.view.isHidden == false {
            notesController!.resizeContentSize()
            notesController!.notesTxtVw.string = forPage.notes
        }
        
        if widgetsController!.view.isHidden == false {
            widgetsController!.resizeContentSize()
            NotificationCenter.default.post(name: Notification.Name("loadWidget"), object: currentDocument!)
        }
        
    }
    
    private func openBrowsePanel(type: String) {
        
        guard self.currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = false
        imgBrowsePanel.canChooseDirectories = false
        imgBrowsePanel.allowedFileTypes = [type]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if result == NSApplication.ModalResponse.OK {
                
                let fileName = "\(self.currentDocument!.getFileNamePrefix())\(Util.shared.formatPageNum(num: currentPage.number + 1))"
                
                currentPage.src = fileName
                
                switch type {
                    
                case FileExtensions.MP3:
                    
                    self.currentDocument!.addAssetsWrappersFile(name: "\(fileName).\(type)", path: imgBrowsePanel.url!, to: FileNames.AUDIO_DIR)

                case FileExtensions.MP4:
                    
                    self.currentDocument!.addAssetsWrappersFile(name: "\(fileName).\(type)", path: imgBrowsePanel.url!, to: FileNames.VIDEO_DIR)
                    
                case FileExtensions.JPG, FileExtensions.PNG, FileExtensions.SVG:
                    
                    self.currentDocument!.addAssetsWrappersFile(name: "\(fileName).\(type)", path: imgBrowsePanel.url!, to: FileNames.PAGES_DIR)
                    
                default:
                    break
                }
                
                //self.currentDocument!.save(nil)
                self.currentDocument!.updateChangeCount(.changeDone)
                self.setDisplay(forPage: currentPage)
                
            }
            
        } )
        
    }
    
}
