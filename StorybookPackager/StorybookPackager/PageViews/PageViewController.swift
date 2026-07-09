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
    @IBOutlet weak var embedHtmlStackView: NSStackView!
    @IBOutlet weak var embedHtmlCb: NSButton!
    @IBOutlet weak var preventAutoplayCb: NSButton!
    @IBOutlet weak var defaultPlayerStackView: NSStackView!
    @IBOutlet weak var defaultPlayerCb: NSButton!
    
    @IBOutlet weak var confirmTitleBtn: NSButton!
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
        
        switch type {
        case PageTypes.FILL_IN_THE_BLANK:
            
            currentPage.type = PageTypes.QUIZ
            
            let fibQ = FillInTheBlank()
            
            fibQ.question = currentPage.quiz.question
            fibQ.choices = currentPage.quiz.choices
            fibQ.answer = currentPage.quiz.answer
            fibQ.random = currentPage.quiz.random
            fibQ.feedback = currentPage.quiz.feedback
            
            currentPage.quiz = fibQ
            
        case PageTypes.SHORT_ANSWER:
            
            currentPage.type = PageTypes.QUIZ
            
            let saQ = ShortAnswer()
            
            saQ.question = currentPage.quiz.question
            saQ.choices = currentPage.quiz.choices
            saQ.answer = currentPage.quiz.answer
            saQ.random = currentPage.quiz.random
            saQ.feedback = currentPage.quiz.feedback
            
            currentPage.quiz = saQ
            
        case PageTypes.MULTIPLE_CHOICE, QuizTypes.MULTIPLE_CHOICE:
            
            currentPage.type = PageTypes.QUIZ
            
            let mcQ = MultipleChoiceSingle()
            
            mcQ.question = currentPage.quiz.question
            mcQ.choices = currentPage.quiz.choices
            mcQ.answer = currentPage.quiz.answer
            mcQ.random = currentPage.quiz.random
            mcQ.feedback = currentPage.quiz.feedback
            
            currentPage.quiz = mcQ
            
        case PageTypes.MULTIPLE_ANSWER, QuizTypes.MULTIPLE_ANSWER:
            
            currentPage.type = PageTypes.QUIZ
            
            let maQ = MultipleChoiceMultiple()
            
            maQ.question = currentPage.quiz.question
            maQ.choices = currentPage.quiz.choices
            maQ.answer = currentPage.quiz.answer
            maQ.random = currentPage.quiz.random
            maQ.feedback = currentPage.quiz.feedback
            
            currentPage.quiz = maQ
            
        case PageTypes.HTML:
            
            currentPage.type = type
            
            if embedHtmlCb.state == .on {
                currentPage.embed = "true"
            } else {
                currentPage.embed = "false"
            }
            
        default:
            currentPage.type = type
        }
        
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: currentDocument!)
        currentDocument!.updateChangeCount(.changeDone)
        setUIs()

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
        
        let newValue = Util.shared.cleanString(str: sender.stringValue)
        
        sender.stringValue = newValue
        
        if (newValue != currentPage.src) {
            
            currentPage.src = newValue
            setDisplay(forPage: currentPage)
            currentDocument!.updateChangeCount(.changeDone)
            
        }
        
    }
    
    @IBAction func confirmTitle(_ sender: NSButton) {
        
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        titleTxtFld.stringValue = currentPage.title.trimmingCharacters(in: ["[", "]", " "])
        
        currentPage.title = Util.shared.cleanString(str: titleTxtFld.stringValue)
        
        if currentPage.type == PageTypes.SECTION {
            pageHeaderLbl.stringValue = "Section \(currentPage.number + 1): \(titleTxtFld.stringValue)"
        } else {
            pageHeaderLbl.stringValue = "Page \(currentPage.number + 1): \(titleTxtFld.stringValue)"
        }
        
        confirmTitleBtn.isHidden = true
        confirmTitleBtn.isEnabled = false
        
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: currentDocument!)
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    @IBAction func onEmbedSelect(_ sender: NSButton) {
        
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        if sender.state == .on {
            currentPage.embed = "true"
        } else {
            currentPage.embed = "false"
        }
        
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    @IBAction func onPreventAutoplaySelect(_ sender: NSButton) {
        
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        if sender.state == .on {
            currentPage.preventAutoplay = "true"
        } else {
            currentPage.preventAutoplay = "false"
        }
        
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    @IBAction func onDefaultPlayerSelect(_ sender: NSButton) {
        
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        if sender.state == .on {
            currentPage.useDefaultPlayer = "true"
        } else {
            currentPage.useDefaultPlayer = "false"
        }
        
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    /*** NOTIFICATION METHODS ***/
    
    // on title editing
    func controlTextDidChange(_ sender: Notification) {

        guard let tf = (sender.object as? NSTextField) else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        if currentPage.type == PageTypes.SECTION {
            pageHeaderLbl.stringValue = "Section \(currentPage.number + 1): \(tf.stringValue)"
        } else {
            pageHeaderLbl.stringValue = "Page \(currentPage.number + 1): \(tf.stringValue)"
        }
        
        currentPage.title = Util.shared.cleanString(str: tf.stringValue)
        
        if Util.shared.needToConfirmTitle(string: tf.stringValue) {
            confirmTitleBtn.isHidden = false
            confirmTitleBtn.isEnabled = true
        } else {
            confirmTitleBtn.isHidden = true
            confirmTitleBtn.isEnabled = false
        }
        
        currentDocument!.updateChangeCount(.changeDone)
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: currentDocument!)
        
    }
    
    // on title editing ended
    @IBAction func titleEndEditing(_ sender: NSTextField) {
        
        guard let currentPageIndex = currentDocument?.currentPageIndex.first else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[currentPageIndex] else { return }
        
        let title = Util.shared.cleanString(str: sender.stringValue)
        
        if title.isEmpty {
            
            currentPage.title = "[Untitled]"
            sender.stringValue = "[Untitled]"
            confirmTitleBtn.isHidden = false
            confirmTitleBtn.isEnabled = true
            
            currentDocument!.updateChangeCount(.changeDone)
            NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: currentDocument!)
            
        }
        
    }
    
    // on notes editing ended
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
        
        let pageTitle = currentPage.title

        // set page header title
        if currentPage.type == PageTypes.SECTION {
            
            pageHeaderLbl.stringValue = "Section \(currentPage.number + 1): \(pageTitle)"
            
            // set page title
            titleTxtFld.stringValue = pageTitle
            
            if Util.shared.needToConfirmTitle(string: pageTitle) {
                confirmTitleBtn.isEnabled = true
            } else {
                confirmTitleBtn.isEnabled = false
            }
            
            return // end function because the rest does not apply
            
        }
        
        /*** if not a section... continues ***/
        
        pageHeaderLbl.stringValue = "Page \(currentPage.number + 1): \(pageTitle)"
        
        // set the page type
        if currentPage.type != PageTypes.QUIZ {
            
            typePopUpBtn.selectItem(at: Util.shared.getPageTypeIndex(type: currentPage.type, collection: typePopUpBtn.itemTitles))
            
        } else {
            
            var quizType = currentPage.quiz.type
            
            if quizType == QuizTypes.MULTIPLE_CHOICE {
                quizType = PageTypes.MULTIPLE_CHOICE
            } else if quizType == QuizTypes.MULTIPLE_ANSWER {
                quizType = PageTypes.MULTIPLE_ANSWER
            }
            
            quizType = quizType.lowercased()
            
            typePopUpBtn.selectItem(at: Util.shared.getPageTypeIndex(type: quizType, collection: typePopUpBtn.itemTitles))
            
        }
        
        // set the page transition; set to none if empty
        if !currentPage.transition.isEmpty {
            transitionPopUpBtn.selectItem(withTitle: currentPage.transition)
        } else {
            transitionPopUpBtn.selectItem(at: 0)
        }
        
        // set the page prevent autoplay attribute
        if currentPage.type != PageTypes.IMAGE && currentPage.type != PageTypes.QUIZ {
            if currentPage.preventAutoplay == "true" {
                preventAutoplayCb.state = .on
            } else {
                preventAutoplayCb.state = .off
            }
        }
        
        // set the page use default player attribute (for youtube)
        if currentPage.type == PageTypes.YOUTUBE {
            
            if currentPage.useDefaultPlayer == "true" || currentPage.useDefaultPlayer == "" {
                defaultPlayerCb.state = .on
            } else {
                defaultPlayerCb.state = .off
            }
        }
        
        // set embed atrribute for HTML page type
        if currentPage.type == PageTypes.HTML {
            
            if currentPage.embed == "true" || currentPage.embed == "yes" || currentPage.embed == "" {
                embedHtmlCb.state = .on
            } else {
                embedHtmlCb.state = .off
            }
        }
        
        // set page title
        titleTxtFld.stringValue = pageTitle
        
        if Util.shared.needToConfirmTitle(string: pageTitle) {
            confirmTitleBtn.isHidden = false
            confirmTitleBtn.isEnabled = true
        } else {
            confirmTitleBtn.isHidden = true
            confirmTitleBtn.isEnabled = false
        }
        
        // set video id
        videoIdTxtFld.stringValue = currentPage.src
        
    }
    
    private func setDisplay(forPage: Page) {

        let pageImgType = currentDocument!.getXmlObj().pageImgFormat
        let pageSrc = forPage.src
        var childController: NSViewController? = nil
        
        // reset view
        if dynamicContentView.isHidden == false {
            
            dynamicContentView.constraints[1].constant = 360
            
            for view in dynamicContentView.subviews {
                view.removeFromSuperview()
            }
            
        }
        
        if notesWidgetsContainer.isHidden == false {
            notesWidgetsContainer.frame = NSRect(x: 0, y: 0, width: notesWidgetsStackView.frame.size.width, height: 210)
        }
        
        // get new view
        switch forPage.type {
            
        case PageTypes.SECTION:
            
            typeTransitionStackView.isHidden = true
            embedHtmlStackView.isHidden = true
            embedHtmlCb.isHidden = true
            defaultPlayerStackView.isHidden = true
            defaultPlayerCb.isHidden = true
            preventAutoplayCb.isHidden = true
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = true
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = true
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = true
            notesWidgetsStackView.isHidden = true
            spaceFiller.isHidden = false
            
        case PageTypes.IMAGE:
            
            typeTransitionStackView.isHidden = false
            embedHtmlStackView.isHidden = true
            defaultPlayerStackView.isHidden = true
            defaultPlayerCb.isHidden = true
            preventAutoplayCb.isHidden = true
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = false
            setImageBtn.isHidden = false
            setAudioBtn.isHidden = true
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            spaceFiller.isHidden = true
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.IMAGE_VIEW) as! ImageViewController
            addChild(childController!)
            dynamicContentView.addSubview(childController!.view)
            (childController as! ImageViewController).fileType = pageImgType
            (childController as! ImageViewController).file = currentDocument!.getAssetFileWrapper(name: "\(pageSrc).\(pageImgType)", at: FileNames.PAGES_DIR)
            (childController as! ImageViewController).setImage()
            
        case PageTypes.IMAGE_AUDIO:
            
            typeTransitionStackView.isHidden = false
            embedHtmlStackView.isHidden = true
            defaultPlayerStackView.isHidden = true
            defaultPlayerCb.isHidden = true
            preventAutoplayCb.isHidden = false
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = false
            setImageBtn.isHidden = false
            setAudioBtn.isHidden = false
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            spaceFiller.isHidden = true
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.IMAGE_AUDIO_VIEW) as! ImageAudioViewController
            addChild(childController!)
            dynamicContentView.addSubview(childController!.view)
            (childController as! ImageAudioViewController).fileType = pageImgType
            (childController as! ImageAudioViewController).file = currentDocument!.getAssetFileWrapper(name: "\(pageSrc).\(pageImgType)", at: FileNames.PAGES_DIR)
            (childController as! ImageAudioViewController).audio = currentDocument!.getAssetFileWrapper(name: "\(pageSrc).\(FileExtensions.MP3)", at: FileNames.AUDIO_DIR)
            (childController as! ImageAudioViewController).setImage()
            
        case PageTypes.BUNDLE:
            
            typeTransitionStackView.isHidden = false
            embedHtmlStackView.isHidden = true
            defaultPlayerStackView.isHidden = true
            defaultPlayerCb.isHidden = true
            preventAutoplayCb.isHidden = false
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = false
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = false
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            spaceFiller.isHidden = true
            
            dynamicContentView.constraints[1].constant = 276
            
            notesWidgetsContainer.frame = NSRect(x: 0, y: 0, width: notesWidgetsStackView.frame.size.width, height: 294)
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.BUNDLE_VIEW) as! BundleViewController
            
            addChild(childController!)
            
            dynamicContentView.addSubview(childController!.view)
            
            (childController as! BundleViewController).fileType = pageImgType
            (childController as! BundleViewController).currentDocument = currentDocument!
            (childController as! BundleViewController).loadBundleFrames()
            
        case PageTypes.QUIZ:
            
            typeTransitionStackView.isHidden = false
            embedHtmlStackView.isHidden = true
            defaultPlayerStackView.isHidden = true
            defaultPlayerCb.isHidden = true
            preventAutoplayCb.isHidden = true
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = true
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = true
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = true
            spaceFiller.isHidden = true
            
            dynamicContentView.constraints[1].constant = 597

            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.QUIZ_VIEW) as! QuizViewController
            addChild(childController!)
            dynamicContentView.addSubview(childController!.view)
            
            (childController as! QuizViewController).currentDocument = currentDocument!
            (childController as! QuizViewController).setQuestion()
            
        case PageTypes.HTML:
            
            typeTransitionStackView.isHidden = false
            embedHtmlStackView.isHidden = false
            defaultPlayerStackView.isHidden = true
            defaultPlayerCb.isHidden = true
            preventAutoplayCb.isHidden = false
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = false
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = false
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            spaceFiller.isHidden = true
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.HTML_VIEW) as! HtmlViewController
            addChild(childController!)
            dynamicContentView.addSubview(childController!.view)
            
            (childController as! HtmlViewController).currentDocument = currentDocument!
            (childController as! HtmlViewController).setHtml();
            
        case PageTypes.KALTURA:
            
            typeTransitionStackView.isHidden = false
            embedHtmlStackView.isHidden = true
            defaultPlayerStackView.isHidden = true
            defaultPlayerCb.isHidden = true
            preventAutoplayCb.isHidden = false
            videoIdStackView.isHidden = false
            sourcesStackView.isHidden = true
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = true
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            spaceFiller.isHidden = true
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.VIDEO_VIEW) as! VideoViewController
            addChild(childController!)
            dynamicContentView.addSubview(childController!.view)
            (childController as! VideoViewController).videoId = pageSrc
            (childController as! VideoViewController).setKalturaVideo()
            
        case PageTypes.VIMEO, PageTypes.YOUTUBE:
            
            typeTransitionStackView.isHidden = false
            embedHtmlStackView.isHidden = true
            preventAutoplayCb.isHidden = false
            videoIdStackView.isHidden = false
            sourcesStackView.isHidden = true
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = true
            setVideoBtn.isHidden = true
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            spaceFiller.isHidden = true
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.STREAMING_VIEW) as! StreamingViewController
            dynamicContentView.addSubview(childController!.view)
            
            if forPage.type == PageTypes.YOUTUBE {
                defaultPlayerStackView.isHidden = false
                defaultPlayerCb.isHidden = false
                (childController as! StreamingViewController).youtubeId = pageSrc
            } else {
                defaultPlayerStackView.isHidden = true
                defaultPlayerCb.isHidden = true
                (childController as! StreamingViewController).vimeoId = pageSrc
            }
            
            (childController as! StreamingViewController).setVideo()
            
        case PageTypes.VIDEO:
            
            typeTransitionStackView.isHidden = false
            embedHtmlStackView.isHidden = true
            preventAutoplayCb.isHidden = false
            videoIdStackView.isHidden = true
            sourcesStackView.isHidden = false
            setImageBtn.isHidden = true
            setAudioBtn.isHidden = true
            setVideoBtn.isHidden = false
            dynamicContentView.isHidden = false
            notesWidgetsStackView.isHidden = false
            spaceFiller.isHidden = true
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.VIDEO_VIEW) as! VideoViewController
            addChild(childController!)
            dynamicContentView.addSubview(childController!.view)
            
            (childController as! VideoViewController).videoUrl = URL(string: "\(currentDocument!.fileURL!.absoluteString)assets/video/\(pageSrc).\(FileExtensions.MP4)")
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
                
                currentPage.src = Util.shared.cleanString(str: fileName)
                
                switch type {
                    
                case FileExtensions.MP3:
                    
                    self.currentDocument!.addAssetsWrappersFile(name: "\(fileName).\(type)", path: imgBrowsePanel.url!, to: FileNames.AUDIO_DIR)

                case FileExtensions.MP4:
                    
                    self.currentDocument!.addAssetsWrappersFile(name: "\(fileName).\(type)", path: imgBrowsePanel.url!, to: FileNames.VIDEO_DIR)
                    
                case FileExtensions.JPG, FileExtensions.JPEG, FileExtensions.PNG, FileExtensions.SVG:
                    
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
