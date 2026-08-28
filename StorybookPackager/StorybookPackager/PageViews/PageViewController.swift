//
//  PageViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/25/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa
import AVFoundation
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

    /// The frames panel of a bundle slide is hosted here, beside the notes, rather than inside the
    /// slide preview where it used to squeeze the slide into two thirds of the width. The panel
    /// itself still belongs to BundleViewController — only where it is shown moves.
    @IBOutlet weak var framesColumn: NSView!
    @IBOutlet weak var framesHost: NSView!
    @IBOutlet weak var framesHeadingLbl: NSTextField!
    
    var currentDocument: Document?
    private let prefSettings = UserDefaults.standard
    private var notesController: NotesViewController?
    private var widgetsController: WidgetsViewController?

    /// Where a slide's video was set from, for the slides whose video has been set or replaced since
    /// the presentation was last saved — the preview plays that file until the presentation holds a
    /// copy of its own.
    ///
    /// Keyed by the slide's source name, which is what a slide keeps hold of between one save and
    /// the next: adding, reordering, or deleting any page rebuilds the whole page list out of fresh
    /// copies, so the slide objects themselves are not the same objects afterwards, and a key made
    /// out of one would stop matching the slide it was made for. A source name is only rewritten by
    /// the save itself, which is also what empties this.
    private var unsavedVideo: [String: URL] = [:]

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
            pin(notesController!.view, to: notesWidgetsContainer)
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
            pin(widgetsController!.view, to: notesWidgetsContainer)
            widgetsController!.view.isHidden = true
        }
        
    }
    
    /// Fills `container` with `view`. The notes and widgets panes used to size themselves by
    /// copying their superview's frame on every appearance, which only held until the next layout
    /// pass — and the container itself had no height at all, so the height was hand-set in code
    /// from two different places. Both are now ordinary constraints.
    private func pin(_ view: NSView, to container: NSView) {

        view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

    }

    /// Shows a bundle slide's frames panel beside the notes.
    ///
    /// The panel is moved, not rebuilt: its table, buttons, and every outlet and action on them
    /// still belong to BundleViewController, which is what a target/action connection cares about —
    /// not where the view sits. That keeps the frame editing logic where it is while the slide
    /// preview gets its full width back.
    private func attachFramesPanel(from controller: BundleViewController) {

        guard let panel = controller.framesPanel else { return }

        panel.removeFromSuperview()
        framesHost.addSubview(panel)
        pin(panel, to: framesHost)

        framesColumn.isHidden = false

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
        
        // The frames panel belongs to whichever bundle slide is on screen; the controller holding it
        // is thrown away on every slide change, so its view goes with it.
        for view in framesHost.subviews {
            view.removeFromSuperview()
        }

        // The column, not its contents: the row detaches hidden views, so hiding the whole column
        // takes its spacing with it. Hiding only what is inside leaves a gap beside the notes.
        framesColumn.isHidden = true
        
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
            // Guarded like the bundle editor: built from an empty base these read ".jpg" and
            // ".mp3", which are real files in a package written by 1.9.9 — so a slide holding
            // nothing previewed a stray belonging to no slide at all.
            (childController as! ImageAudioViewController).file = pageSrc.isEmpty ? nil : currentDocument!.getAssetFileWrapper(name: "\(pageSrc).\(pageImgType)", at: FileNames.PAGES_DIR)
            (childController as! ImageAudioViewController).audio = pageSrc.isEmpty ? nil : currentDocument!.getAssetFileWrapper(name: "\(pageSrc).\(FileExtensions.MP3)", at: FileNames.AUDIO_DIR)
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
            
            // A bundle slide is laid out like every other slide now: full-size preview above, notes
            // below. What used to make it the exception — a preview cut down to 276 to make room for
            // the frames panel inside it, and a notes row grown to 294 to match — is gone with the
            // panel's move out to the notes row.
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.BUNDLE_VIEW) as! BundleViewController
            
            addChild(childController!)
            
            dynamicContentView.addSubview(childController!.view)
            
            (childController as! BundleViewController).controlsPinned = pinControlsCb.state == .on
            (childController as! BundleViewController).fileType = pageImgType
            (childController as! BundleViewController).currentDocument = currentDocument!
            (childController as! BundleViewController).captions = captionTrack(for: forPage)
            (childController as! BundleViewController).loadBundleFrames()

            attachFramesPanel(from: childController as! BundleViewController)
            
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
            
            // A video set since the presentation was last saved is still only in memory, so the copy
            // the player would find under the presentation's own name is either missing or the video
            // that was just replaced. Play the file it was set from until there is a saved copy.
            // A presentation that has never been saved has no URL to build the saved copy's path
            // from, and there is no saved copy to play either — force-unwrapping it trapped as soon
            // as a video slide was selected in a new presentation.
            let savedVideoURL = currentDocument!.fileURL.flatMap {
                URL(string: "\($0.absoluteString)assets/video/\(pageSrc).\(FileExtensions.MP4)")
            }

            (childController as! VideoViewController).videoUrl = previewVideoURL(for: forPage, savedAt: savedVideoURL)
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
        configureVideoDrop(for: forPage)

        // set notes if applicable
        guard forPage.type != PageTypes.QUIZ && forPage.type != PageTypes.SECTION else { return }
        guard notesController != nil && widgetsController != nil else { return }
        
        if notesController!.view.isHidden == false {
            notesController!.notesTxtVw.string = forPage.notes
        }
        
        if widgetsController!.view.isHidden == false {
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

    /// The file a slide's narration is stored as, or nil when it has none.
    ///
    /// A widget slide keeps its narration in its own `audio` reference rather than under `src` —
    /// `src` names the widget's folder — so every other slide type asks by base name and this one
    /// asks by reference.
    private func audioFileName(for page: Page) -> String? {

        if page.type == PageTypes.HTML {
            return page.audio.isEmpty ? nil : (page.audio as NSString).lastPathComponent
        }

        return page.src.isEmpty ? nil : "\(page.src).\(FileExtensions.MP3)"

    }

    private func hasNarration(_ page: Page) -> Bool {

        guard let name = audioFileName(for: page) else { return false }

        return currentDocument?.fileExistsInAssetsDir(fileName: name, subDirName: FileNames.AUDIO_DIR, asBool: true) as? Bool ?? false

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
        setAudioBtn.title = hasNarration(page) ? "Remove Audio" : "Set Audio"
        setVideoBtn.title = hasAsset(ext: FileExtensions.MP4, in: FileNames.VIDEO_DIR) ? "Remove Video" : "Set Video"

        guard let captionDirectory = CaptionTrack.assetDirectory(forPageType: page.type) else {
            setCaptionsBtn.title = "Set Captions"
            return
        }

        setCaptionsBtn.title = hasAsset(ext: FileExtensions.VTT, in: captionDirectory) ? "Remove Captions" : "Set Captions"

    }

    // MARK: - a video dropped straight onto the slide

    /// What the preview should actually play: the file the slide's video was set from when that has
    /// not been written into the presentation yet, and the presentation's own copy once it has.
    /// Saving writes every pending video at once, so a saved presentation has nothing left pending.
    private func previewVideoURL(for page: Page, savedAt saved: URL?) -> URL? {

        if currentDocument?.isDocumentEdited == false {
            unsavedVideo.removeAll()
        }

        return unsavedVideo[page.src] ?? saved

    }

    /// The preview area of a video slide takes a single MP4 dropped onto it, whatever the file is
    /// called: the slide it lands on is the slide on screen, so there is no file name to read a page
    /// number out of. Every other slide type leaves the drop alone — those go to the import box,
    /// where the file name is what decides where the file belongs.
    private func configureVideoDrop(for page: Page) {

        guard let target = dynamicContentView as? VideoDropTargetView else { return }

        guard VideoDropTarget.accepts(pageType: page.type) else {

            target.isDropEnabled = false
            target.onDrop = nil

            return

        }

        // A Kaltura, YouTube, or Vimeo slide is already playing something, even though the
        // presentation doesn't hold the file.
        let hasVideo = page.type != PageTypes.VIDEO || hasAsset(ext: FileExtensions.MP4, in: FileNames.VIDEO_DIR)

        target.dropMessage = hasVideo ? "Drop an MP4 to replace this slide's video"
                                      : "Drop an MP4 to set this slide's video"

        target.onDrop = { [weak self] url in self?.applyDroppedVideo(url) }
        target.isDropEnabled = true

    }

    /// Puts the dropped file on the slide. A slide that was streaming from somewhere else becomes a
    /// video slide playing the presentation's own copy, which is what dropping a file on it says;
    /// the streaming ID it was playing is not kept, the same as re-typing the slide by hand.
    private func applyDroppedVideo(_ url: URL) {

        guard let document = currentDocument, let page = currentPage() else { return }

        let previousSrc = page.src
        let previousType = page.type

        // Captions are timed to the video they were written for. Replacing the video silently is
        // the point of the drop, but leaving captions that describe the video that just went away
        // is not — so this is the one thing the drop stops to ask about.
        var clearCaptions = false

        if previousType == PageTypes.VIDEO, let track = captionTrack(for: page), let lastCue = track.cues.last {

            let duration = CMTimeGetSeconds(AVURLAsset(url: url).duration)

            if !VideoDropTarget.captionsFit(lastCueEnd: lastCue.end, videoDuration: duration) {

                let alert = NSAlert()

                alert.alertStyle = .warning
                alert.messageText = "This slide's captions don't match the video you dropped."
                alert.informativeText = "They were timed to the video being replaced."
                alert.addButton(withTitle: "Clear Captions")
                alert.addButton(withTitle: "Cancel")

                guard alert.runModal() == .alertFirstButtonReturn else { return }

                clearCaptions = true

            }

        }

        // The slide's own name, reserved if it hasn't got one yet — not one rebuilt from where the
        // slide currently sits, which on a slide inserted since the last save is a name whose files
        // still belong to its neighbour.
        let name = document.assetBaseName(for: page)

        page.type = PageTypes.VIDEO
        page.src = name

        addVideoAsset(named: "\(name).\(FileExtensions.MP4)", from: url, to: document)

        unsavedVideo[name] = url

        settleCaptions(from: previousSrc, to: name, wasType: previousType, clearing: clearCaptions, in: document)

        document.updateChangeCount(.changeDone)

        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: document)

        setUIs()

    }

    /// Writes an asset the slide will play, and drops the "~" snapshot beside it. That snapshot is
    /// the copy the save path renames assets *from*, and it is kept if it is already there — left
    /// behind, it holds the video that was just replaced and would be written back over this one
    /// the next time the slide's assets are renamed.
    private func addVideoAsset(named fileName: String, from url: URL, to document: Document) {

        document.addAssetsWrappersFile(name: fileName, path: url, to: FileNames.VIDEO_DIR)
        document.removeFileFromAssetsDir(file: "~\(fileName)", subDir: FileNames.VIDEO_DIR)

    }

    /// Captions the user chose to keep follow the video onto its new name; captions that no longer
    /// describe it are dropped. A slide that was streaming had no captions of its own to begin with.
    private func settleCaptions(from previousSrc: String, to name: String, wasType previousType: String, clearing clear: Bool, in document: Document) {

        guard previousType == PageTypes.VIDEO, !previousSrc.isEmpty else { return }

        let previousFile = CaptionTrack.fileName(forPageSource: previousSrc)
        let newFile = CaptionTrack.fileName(forPageSource: name)

        func forget(_ file: String) {
            document.removeFileFromAssetsDir(file: file, subDir: FileNames.VIDEO_DIR)
            document.removeFileFromAssetsDir(file: "~\(file)", subDir: FileNames.VIDEO_DIR)
        }

        if clear {
            forget(previousFile)
            return
        }

        guard previousFile != newFile,
              let wrapper = document.getAssetFileWrapper(name: previousFile, at: FileNames.VIDEO_DIR),
              let contents = wrapper.regularFileContents else { return }

        document.addAssetsWrappersFile(name: newFile,
                                       file: FileWrapper(regularFileWithContents: contents),
                                       to: FileNames.VIDEO_DIR)

        document.removeFileFromAssetsDir(file: "~\(newFile)", subDir: FileNames.VIDEO_DIR)

        forget(previousFile)

    }

    /// Taking a source off a slide is the one thing here that destroys work, so it asks — and says
    /// plainly that the file it is dropping is the presentation's copy, not the original on disk.
    private func removeAsset(ext: String, from directory: String, named label: String) {

        guard let document = currentDocument, let page = currentPage() else { return }

        let isWidgetNarration = ext == FileExtensions.MP3 && page.type == PageTypes.HTML

        guard let fileName = isWidgetNarration ? audioFileName(for: page) : "\(page.src).\(ext)" else { return }

        let alert = NSAlert()

        alert.alertStyle = .warning
        alert.messageText = "Remove the \(label) from page \(page.number + 1)?"
        alert.informativeText = "\(fileName) is dropped from the presentation when it is next saved. The file you imported it from is left where it is."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        document.removeFileFromAssetsDir(file: fileName, subDir: directory)

        // The reference goes with the file, or the slide still claims narration it no longer has.
        if isWidgetNarration { page.audio = "" }

        // Nothing left to preview from the file it was set from either.
        if ext == FileExtensions.MP4 {
            unsavedVideo.removeValue(forKey: page.src)
        }

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

            // The "~" snapshot beside them holds whatever they replaced — the bulk import leaves one
            // beside every caption file it writes — and the next reorder would rename from it.
            document.removeFileFromAssetsDir(file: "~\(CaptionTrack.fileName(forPageSource: page.src))", subDir: directory)

            document.updateChangeCount(.changeDone)

            self.setDisplay(forPage: page)
            NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: document)

        })

    }

    /// The slide's captions, ready to draw. Nil when the slide has none, or when what it has holds
    /// no cue this can show.
    private func captionTrack(for page: Page) -> CaptionTrack? {

        guard !page.src.isEmpty,
              let directory = CaptionTrack.assetDirectory(forPageType: page.type),
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
        
        // Every slide image format is offered, not only the one this presentation is set to: picking
        // a file in another format is one of the ways an author moves the whole presentation to that
        // format, which setSlideImage(from:fileName:page:) asks about. A JPG document takes either
        // spelling of JPEG; it is written back under the canonical extension, so there is nothing
        // for the user to reconcile.
        imgBrowsePanel.allowedFileTypes = SlideImageFormat.isSlideImage(type)
            ? SlideImageFormat.all + [FileExtensions.JPEG]
            : [type]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            guard result == NSApplication.ModalResponse.OK, let chosenURL = imgBrowsePanel.url else { return }
            
            // Pinned to the slide the file was chosen for, here and not later. autoApplyOCRTitle
            // checks it against currentPageIndex.first, which is the raw index into
            // getXmlObjPages() (section rows included) — NOT page.number, a pages-only counter that
            // skips section headers. Setting an image can now take a modal question and a
            // conversion first, so reading the selection at the end of all that is reading it from
            // a different moment than the one the choice was made in.
            guard let pageIndex = self.currentDocument!.currentPageIndex.first else { return }
            
            // The slide's own base name, worked out once here and threaded through every branch
            // below and into finishSettingSource. A slide that has one keeps it; one that hasn't
            // takes a name reserved free across every slot a slide can occupy. Rebuilt from the
            // slide's position instead — which is what this used to do — a slide inserted since the
            // last save was handed the name its neighbour's files are still filed under, and setting
            // one source here overwrote the neighbour's while borrowing the rest of its files.
            let fileName = self.currentDocument!.assetBaseName(for: currentPage)
            
            // `src` is deliberately NOT assigned here. Setting a slide image can put a question up
            // first — choosing a JPEG in an SVG presentation changes every slide — and an assignment
            // made before that question survives a Cancel: the page would keep a src it has no file
            // for, orphaning the narration audio filed under its old one, with nothing marking the
            // document as changed. Each branch below assigns it at the point it commits.
            switch type {
                
            case FileExtensions.MP3:
                
                // A widget slide's src names its folder, not a base for media, so its narration is
                // recorded as a reference instead. Overwriting src here orphaned the widget's whole
                // folder — and now that the save reclaims what nothing points at, orphaned means gone.
                if currentPage.type == PageTypes.HTML {
                    currentPage.audio = "\(fileName).\(type)"
                } else {
                    currentPage.src = fileName
                }

                self.currentDocument!.addAssetsWrappersFile(name: "\(fileName).\(type)", path: chosenURL, to: FileNames.AUDIO_DIR)

                // The "~" snapshot is what the next save renames this slide's audio *from*. Left
                // behind, it still holds whatever this just replaced.
                self.currentDocument!.removeFileFromAssetsDir(file: "~\(fileName).\(type)", subDir: FileNames.AUDIO_DIR)

                self.finishSettingSource(type: type, fileName: fileName, page: currentPage, pageIndex: pageIndex)

            case FileExtensions.MP4:
                
                currentPage.src = fileName
                self.currentDocument!.addAssetsWrappersFile(name: "\(fileName).\(type)", path: chosenURL, to: FileNames.VIDEO_DIR)
                self.currentDocument!.removeFileFromAssetsDir(file: "~\(fileName).\(type)", subDir: FileNames.VIDEO_DIR)

                // Until the presentation is saved its own copy is only in memory, so the preview
                // plays the file this was set from — the same as a video dropped on the slide.
                self.unsavedVideo[currentPage.src] = chosenURL
                
                self.finishSettingSource(type: type, fileName: fileName, page: currentPage, pageIndex: pageIndex)
                
            case FileExtensions.JPG, FileExtensions.JPEG, FileExtensions.PNG, FileExtensions.SVG:

                self.setSlideImage(from: chosenURL, fileName: fileName, page: currentPage, pageIndex: pageIndex)

            default:
                break
                
            }
            
        } )
        
    }

    // Write a chosen slide image into the presentation, moving the presentation to the file's own
    // format first when it differs. A presentation keeps all of its slide images in one format, so a
    // JPEG picked in an SVG presentation is a change to every slide and not just to this one: it is
    // asked about, and the slides it doesn't cover are converted rather than left behind as orphans
    // for the next save to sweep.
    private func setSlideImage(from url: URL, fileName: String, page: Page, pageIndex: Int) {

        guard let document = currentDocument else { return }

        let chosen = Util.shared.canonicalImageExt(url.pathExtension)
        let current = Util.shared.canonicalImageExt(document.getXmlObj().pageImgFormat)

        // Written under whatever the presentation's format is by the time this runs, which is the
        // chosen one if the switch went ahead.
        let write = { [weak self] in

            // The presentation's format verbatim, NOT its canonical form: every other path that
            // builds this filename — the Set/Remove button, the outline, the save-time sweep —
            // reads pageImgFormat raw, so canonicalising only here would file the image under a
            // name none of them look for.
            let format = document.getXmlObj().pageImgFormat

            page.src = fileName

            document.addAssetsWrappersFile(name: "\(fileName).\(format)", path: url, to: FileNames.PAGES_DIR)
            document.removeFileFromAssetsDir(file: "~\(fileName).\(format)", subDir: FileNames.PAGES_DIR)

            self?.finishSettingSource(type: format, fileName: fileName, page: page, pageIndex: pageIndex)

        }

        guard chosen != current else { write(); return }

        let replacing: Set<String> = ["\(fileName).\(chosen)"]

        // Off the open panel's completion: that sheet is still unwinding, and the confirmation wants
        // the document window to itself.
        DispatchQueue.main.async {

            // Called off at either question, the chosen file is in a format the presentation didn't
            // move to, so it does not go in.
            guard document.confirmAndSwitchPageImageFormat(to: chosen, replacing: replacing, context: .settingOneImage) else { return }

            write()

        }

    }

    // What every "Set …" does once the file is in: redraw the slide, stop the outline marking what
    // it was missing, and read a title off an image if that is turned on.
    private func finishSettingSource(type: String, fileName: String, page: Page, pageIndex: Int) {

        currentDocument!.updateChangeCount(.changeDone)
        setDisplay(forPage: page)

        // The outline marks what a slide is missing, and setting a source is exactly what stops it
        // missing something. Without this the warning and the caption mark stay as they were until
        // the presentation is closed and reopened.
        NotificationCenter.default.post(name: Notification.Name("refreshCell"), object: self.currentDocument!)

        guard SlideImageFormat.isSlideImage(type),
              UserDefaults.standard.bool(forKey: Preferences.AUTO_OCR_TITLE),
              page.type == PageTypes.IMAGE || page.type == PageTypes.IMAGE_AUDIO else { return }

        if type == FileExtensions.SVG {

            // setDisplay(forPage:) just instantiated a fresh child controller and started its async
            // WKWebView render; hook the snapshot callback before it completes.
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
