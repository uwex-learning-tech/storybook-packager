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
    
    @IBOutlet weak var titleCaseBtn: NSButton!
    @IBOutlet weak var ocrTitleBtn: NSButton!
    @IBOutlet weak var titleTxtFld: NSTextField!
    @IBOutlet weak var spaceFiller: NSBox!
    
    @IBOutlet weak var videoIdStackView: NSStackView!
    @IBOutlet weak var videoIdTxtFld: NSTextField!
    
    @IBOutlet weak var sourcesStackView: NSStackView!
    @IBOutlet weak var pinControlsCb: NSButton!
    @IBOutlet weak var setImageBtn: NSButton!
    @IBOutlet weak var setAudioBtn: NSButton!
    @IBOutlet weak var setVideoBtn: NSButton!
    @IBOutlet weak var setCaptionsBtn: NSButton!
    
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

        // Fall back to the cell's "Aa" title when the symbol is unavailable.
        if let symbol = NSImage(systemSymbolName: "textformat", accessibilityDescription: "Apply title case") {
            titleCaseBtn.image = symbol
        } else {
            titleCaseBtn.imagePosition = .noImage
        }

        // Fall back to the cell's "OCR" title when the symbol is unavailable.
        if let symbol = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Guess title from slide image") {
            ocrTitleBtn.image = symbol
        } else {
            ocrTitleBtn.imagePosition = .noImage
        }

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
    
    // Each source button does one of two opposite things depending on what the slide already holds,
    // so what it does has to be legible before it is pressed — the button says "Set" or "Remove",
    // and reads the slide the same way refreshSourceButtons(for:) titled it.
    @IBAction func setPageImage(_ sender: NSButton) {

        guard currentDocument != nil else { return }

        let format = currentDocument!.getXmlObj().pageImgFormat

        if hasAsset(ext: format, in: FileNames.PAGES_DIR) {
            removeAsset(ext: format, from: FileNames.PAGES_DIR, named: "slide image")
        } else {
            openBrowsePanel(type: format)
        }

    }
    
    @IBAction func setPageAudio(_ sender: NSButton) {

        if hasAsset(ext: FileExtensions.MP3, in: FileNames.AUDIO_DIR) {
            removeAsset(ext: FileExtensions.MP3, from: FileNames.AUDIO_DIR, named: "narration audio")
        } else {
            openBrowsePanel(type: FileExtensions.MP3)
        }

    }
    
    @IBAction func setPageVideo(_ sender: NSButton) {

        if hasAsset(ext: FileExtensions.MP4, in: FileNames.VIDEO_DIR) {
            removeAsset(ext: FileExtensions.MP4, from: FileNames.VIDEO_DIR, named: "video")
        } else {
            openBrowsePanel(type: FileExtensions.MP4)
        }

    }

    // The checkbox sits in the Sources row with the rest of the page's controls, but what it pins is
    // the bundle's floating transport, which belongs to the child.
    @IBAction func pinAudioControl(_ sender: NSButton) {
        // The same way the rest of this file finds the slide currently on screen: children are added
        // but never removed, so the live one is the one whose view is actually hosted.
        let hosted = children.first { dynamicContentView.subviews.contains($0.view) }
        (hosted as? BundleViewController)?.setControlsPinned(sender.state == .on)
    }
    
    @IBAction func setPageCaptions(_ sender: NSButton) {

        guard let page = currentPage(), let directory = CaptionTrack.assetDirectory(forPageType: page.type) else { return }

        if hasAsset(ext: FileExtensions.VTT, in: directory) {
            removeAsset(ext: FileExtensions.VTT, from: directory, named: "captions")
        } else {
            importCaptions(into: directory, for: page)
        }

    }
    
    @IBAction func videoIdChange(_ sender: NSTextField) {
        
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        let newValue = sender.sanitize()

        if (newValue != currentPage.src) {
            
            currentPage.src = newValue
            setDisplay(forPage: currentPage)
            currentDocument!.updateChangeCount(.changeDone)
            
        }
        
    }
    
    // Whether the title actions can run right now — drives menu item validation.
    var canApplyTitleCase: Bool {
        guard let index = currentDocument?.currentPageIndex.first,
              let pages = currentDocument?.getXmlObjPages(), index < pages.count else { return false }
        return true
    }

    var canGuessTitle: Bool {
        guard let index = currentDocument?.currentPageIndex.first,
              let pages = currentDocument?.getXmlObjPages(), index < pages.count else { return false }
        let page = pages[index]
        return ocrTitleBtn.isEnabled
            && (page.type == PageTypes.IMAGE || page.type == PageTypes.IMAGE_AUDIO)
            && !page.src.isEmpty
    }

    @IBAction func applyTitleCase(_ sender: Any) {

        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }

        // Commit whatever is still in the field editor, or it would overwrite the recased title when
        // editing eventually ends.
        view.window?.makeFirstResponder(nil)

        let title = Util.shared.titleCase(str: Util.shared.cleanString(str: titleTxtFld.stringValue))

        guard title != currentPage.title else { return }

        currentPage.title = title
        titleTxtFld.stringValue = title

        if currentPage.type == PageTypes.SECTION {
            pageHeaderLbl.stringValue = "Section \(currentPage.number + 1): \(title)"
        } else {
            pageHeaderLbl.stringValue = "Page \(currentPage.number + 1): \(title)"
        }

        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: currentDocument!)
        currentDocument!.updateChangeCount(.changeDone)

    }

    @IBAction func guessTitleFromImage(_ sender: Any) {

        guard let pageIndex = currentDocument?.currentPageIndex.first else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[pageIndex] else { return }

        // Commit whatever is still in the field editor, or it would overwrite the guessed title
        // when editing eventually ends.
        view.window?.makeFirstResponder(nil)

        let imgFormat = currentDocument!.getXmlObj().pageImgFormat
        let source: SlideTitleOCR.Source

        if imgFormat == FileExtensions.SVG {

            // SVGs are rendered by a WKWebView and snapshotted into the child controller's image
            // view once loading finishes; OCR reads that snapshot.
            let hosted = children.first { dynamicContentView.subviews.contains($0.view) }
            let snapshot = (hosted as? ImageViewController)?.imageView.image
                ?? (hosted as? ImageAudioViewController)?.imageView.image

            guard let image = snapshot,
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                Util.shared.showAlert(message: "Slide is still rendering",
                                      informative: "The slide image has not finished rendering yet. Try again in a moment.",
                                      style: .informational)
                return
            }

            source = .cgImage(cgImage)

        } else {

            guard let data = currentDocument!.getAssetFileWrapper(name: "\(currentPage.src).\(imgFormat)", at: FileNames.PAGES_DIR)?.regularFileContents else {
                Util.shared.showAlert(message: "No slide image",
                                      informative: "This page has no slide image to read a title from.",
                                      style: .informational)
                return
            }

            source = .data(data)

        }

        ocrTitleBtn.isEnabled = false

        SlideTitleOCR.guessTitle(from: source) { [weak self] result in

            guard let self = self else { return }

            self.ocrTitleBtn.isEnabled = true

            switch result {

            case .success(let title):

                // Bail if the user moved to another page while recognition ran, so the guess
                // doesn't land on the wrong page.
                guard self.currentDocument?.currentPageIndex.first == pageIndex else { return }
                self.setGuessedTitle(title)

            case .failure(let error):

                if error is SlideTitleOCR.OCRError {
                    Util.shared.showAlert(message: "No title found",
                                          informative: "No readable text was found on the slide image.",
                                          style: .informational)
                } else {
                    Util.shared.showAlert(message: "Could not read the slide image",
                                          informative: error.localizedDescription,
                                          style: .warning)
                }

            }

        }

    }

    private func setGuessedTitle(_ raw: String) {

        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }

        let title = Util.shared.cleanString(str: raw)

        guard !title.isEmpty, title != currentPage.title else { return }

        currentPage.title = title
        titleTxtFld.stringValue = title

        if currentPage.type == PageTypes.SECTION {
            pageHeaderLbl.stringValue = "Section \(currentPage.number + 1): \(title)"
        } else {
            pageHeaderLbl.stringValue = "Page \(currentPage.number + 1): \(title)"
        }

        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: currentDocument!)
        currentDocument!.updateChangeCount(.changeDone)

    }

    private func autoApplyOCRTitle(source: SlideTitleOCR.Source, pageIndex: Int) {

        guard UserDefaults.standard.bool(forKey: Preferences.AUTO_OCR_TITLE) else { return }

        SlideTitleOCR.guessTitle(from: source) { [weak self] result in

            guard let self = self, case .success(let title) = result else { return }

            // Bail if the user moved to another page while recognition ran, so the guess
            // doesn't land on the wrong page.
            guard self.currentDocument?.currentPageIndex.first == pageIndex else { return }
            self.setGuessedTitle(title)

        }

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

        currentDocument!.updateChangeCount(.changeDone)
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: currentDocument!)
        
    }
    
    // on title editing ended
    @IBAction func titleEndEditing(_ sender: NSTextField) {
        
        guard let currentPageIndex = currentDocument?.currentPageIndex.first else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[currentPageIndex] else { return }

        let previousTitle = currentPage.title
        let title = sender.sanitize()

        if title.isEmpty {

            currentPage.title = "[Untitled]"
            sender.stringValue = "[Untitled]"

        } else {

            currentPage.title = title

        }

        // controlTextDidChange sets the header from the raw value while committing the trimmed one,
        // so the header has to be redrawn from what actually landed on the page.
        if currentPage.type == PageTypes.SECTION {
            pageHeaderLbl.stringValue = "Section \(currentPage.number + 1): \(currentPage.title)"
        } else {
            pageHeaderLbl.stringValue = "Page \(currentPage.number + 1): \(currentPage.title)"
        }

        if currentPage.title != previousTitle {
            currentDocument!.updateChangeCount(.changeDone)
            NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: currentDocument!)
        }

    }
    
    // on notes editing ended
    func textDidEndEditing(_ sender: Notification) {
        
        guard let textView = sender.object as? NSTextView else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }

        let notes = textView.sanitize()

        if (notes != currentPage.notes) {
            currentPage.notes = notes
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

            ocrTitleBtn.isEnabled = false

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

        // the OCR title guess only applies to pages backed by a slide image
        ocrTitleBtn.isEnabled = (currentPage.type == PageTypes.IMAGE || currentPage.type == PageTypes.IMAGE_AUDIO) && !currentPage.src.isEmpty

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
            (childController as! ImageAudioViewController).captions = captionTrack(for: forPage)
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
            
            (childController as! BundleViewController).controlsPinned = pinControlsCb.state == .on
            (childController as! BundleViewController).fileType = pageImgType
            (childController as! BundleViewController).currentDocument = currentDocument!
            (childController as! BundleViewController).captions = captionTrack(for: forPage)
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
            (childController as! VideoViewController).captions = captionTrack(for: forPage)
            (childController as! VideoViewController).setVideo()
            
        default:
            break
        }

        // Captions belong to the slide types whose media the presentation itself holds, and only
        // when the sources row is on screen at all.
        setCaptionsBtn.isHidden = sourcesStackView.isHidden || !CaptionTrack.supportsCaptions(pageType: forPage.type)
        // Only a bundle has the floating transport this pins, so it shows with one and not otherwise.
        pinControlsCb.isHidden = forPage.type != PageTypes.BUNDLE

        refreshSourceButtons(for: forPage)
        
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
    
    // MARK: - slide sources

    private func currentPage() -> Page? {

        guard let index = currentDocument?.currentPageIndex.first,
              let pages = currentDocument?.getXmlObjPages(),
              pages.indices.contains(index) else { return nil }

        return pages[index]

    }

    private func hasAsset(ext: String, in directory: String) -> Bool {

        guard let page = currentPage(), !page.src.isEmpty else { return false }

        return currentDocument?.fileExistsInAssetsDir(fileName: "\(page.src).\(ext)",
                                                     subDirName: directory,
                                                     asBool: true) as? Bool ?? false

    }

    /// A source button reads as what it will do. Which half it is on is the slide's answer, not a
    /// remembered state, so this runs on every display of a slide.
    private func refreshSourceButtons(for page: Page) {

        let imageFormat = currentDocument?.getXmlObj().pageImgFormat ?? ""

        setImageBtn.title = hasAsset(ext: imageFormat, in: FileNames.PAGES_DIR) ? "Remove Image" : "Set Image"
        setAudioBtn.title = hasAsset(ext: FileExtensions.MP3, in: FileNames.AUDIO_DIR) ? "Remove Audio" : "Set Audio"
        setVideoBtn.title = hasAsset(ext: FileExtensions.MP4, in: FileNames.VIDEO_DIR) ? "Remove Video" : "Set Video"

        guard let captionDirectory = CaptionTrack.assetDirectory(forPageType: page.type) else {
            setCaptionsBtn.title = "Set Captions"
            return
        }

        setCaptionsBtn.title = hasAsset(ext: FileExtensions.VTT, in: captionDirectory) ? "Remove Captions" : "Set Captions"

    }

    /// Taking a source off a slide is the one thing here that destroys work, so it asks — and says
    /// plainly that the file it is dropping is the presentation's copy, not the original on disk.
    private func removeAsset(ext: String, from directory: String, named label: String) {

        guard let document = currentDocument, let page = currentPage() else { return }

        let fileName = "\(page.src).\(ext)"

        let alert = NSAlert()

        alert.alertStyle = .warning
        alert.messageText = "Remove the \(label) from page \(page.number + 1)?"
        alert.informativeText = "\(fileName) is dropped from the presentation when it is next saved. The file you imported it from is left where it is."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        document.removeFileFromAssetsDir(file: fileName, subDir: directory)

        // The bulk import writes a shadow copy beside every asset it adds; left behind, it would be
        // the file that gets renamed onto this slide's name on the next save.
        document.removeFileFromAssetsDir(file: "~\(fileName)", subDir: directory)

        document.updateChangeCount(.changeDone)

        setDisplay(forPage: page)
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: document)

    }

    /// Captions come in as .vtt or .srt and are stored as the .vtt the player reads, converted by
    /// the same path the bulk import uses so a file that works dropped in works chosen here.
    private func importCaptions(into directory: String, for page: Page) {

        guard let document = currentDocument else { return }

        let mediaExtension = directory == FileNames.VIDEO_DIR ? FileExtensions.MP4 : FileExtensions.MP3

        guard hasAsset(ext: mediaExtension, in: directory) else {

            Util.shared.showAlert(
                message: "This slide has nothing to caption yet",
                informative: "Captions attach to the audio or video on a slide. Set this slide's \(directory == FileNames.VIDEO_DIR ? "video" : "audio") first, then set its captions.",
                style: .warning
            )

            return

        }

        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedFileTypes = [FileExtensions.VTT, FileExtensions.SRT]

        panel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in

            guard result == NSApplication.ModalResponse.OK, let url = panel.url else { return }

            guard let data = try? SubtitleConverter.webVTTData(contentsOf: url) else {

                Util.shared.showAlert(
                    message: "That caption file could not be read",
                    informative: "It holds no captions, or it isn't a caption file at all.",
                    style: .warning
                )

                return

            }

            document.addAssetsWrappersFile(name: CaptionTrack.fileName(forPageSource: page.src),
                                           file: FileWrapper(regularFileWithContents: data),
                                           to: directory)

            document.updateChangeCount(.changeDone)

            self.setDisplay(forPage: page)
            NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: document)

        })

    }

    /// The slide's captions, ready to draw. Nil when the slide has none, or when what it has holds
    /// no cue this can show.
    private func captionTrack(for page: Page) -> CaptionTrack? {

        guard let directory = CaptionTrack.assetDirectory(forPageType: page.type),
              let wrapper = currentDocument?.getAssetFileWrapper(name: CaptionTrack.fileName(forPageSource: page.src), at: directory),
              let contents = wrapper.regularFileContents,
              let text = SubtitleConverter.decodeText(contents) else { return nil }

        return CaptionTrack(webVTT: text)

    }

    private func openBrowsePanel(type: String) {
        
        guard self.currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = false
        imgBrowsePanel.canChooseDirectories = false
        
        // A JPG document accepts a file saved with either spelling; it is written back below under
        // the document's own extension, so there is nothing for the user to reconcile.
        imgBrowsePanel.allowedFileTypes = type == FileExtensions.JPG ? [FileExtensions.JPG, FileExtensions.JPEG] : [type]
        
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

                // The outline marks what a slide is missing, and setting a source is exactly what
                // stops it missing something. Without this the warning and the caption mark stay as
                // they were until the presentation is closed and reopened.
                NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: self.currentDocument!)

                if [FileExtensions.JPG, FileExtensions.JPEG, FileExtensions.PNG, FileExtensions.SVG].contains(type),
                   UserDefaults.standard.bool(forKey: Preferences.AUTO_OCR_TITLE),
                   currentPage.type == PageTypes.IMAGE || currentPage.type == PageTypes.IMAGE_AUDIO {

                    // autoApplyOCRTitle checks this against currentPageIndex.first, which is the raw
                    // index into getXmlObjPages() (section rows included) — NOT currentPage.number
                    // (a pages-only counter that skips section headers, so it diverges as soon as
                    // there's a section above the current page).
                    let pageIndex = self.currentDocument!.currentPageIndex.first!

                    if type == FileExtensions.SVG {

                        // setDisplay(forPage:) just instantiated a fresh child controller and started
                        // its async WKWebView render; hook the snapshot callback before it completes.
                        let hosted = self.children.first { self.dynamicContentView.subviews.contains($0.view) }
                        let setCallback: (NSImage) -> Void = { [weak self] image in
                            guard let self = self, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
                            self.autoApplyOCRTitle(source: .cgImage(cgImage), pageIndex: pageIndex)
                        }
                        (hosted as? ImageViewController)?.onImageRendered = setCallback
                        (hosted as? ImageAudioViewController)?.onImageRendered = setCallback

                    } else if let data = self.currentDocument!.getAssetFileWrapper(name: "\(fileName).\(type)", at: FileNames.PAGES_DIR)?.regularFileContents {

                        self.autoApplyOCRTitle(source: .data(data), pageIndex: pageIndex)

                    }

                }

            }
            
        } )
        
    }
    
}
