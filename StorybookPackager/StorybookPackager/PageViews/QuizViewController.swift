//
//  QuizViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/22/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa
import AVFoundation
import SbXmlParser

class QuizViewController: NSViewController, NSTextViewDelegate {

    @IBOutlet weak var questionTxtVwScroller: NSScrollView!
    @IBOutlet var questionTxtVw: NSTextView!
    @IBOutlet weak var answerContainer: NSView!
    @IBOutlet weak var questionImgBox: NSBox!
    @IBOutlet weak var questionImgBtn: NSButton!
    @IBOutlet weak var questionAudioBtn: NSButton!

    var currentDocument: Document?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        questionTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        questionTxtVw.delegate = self
        
    }
    
    func setQuestion() {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }
        
        let questionImgBoxWidthConstraint = NSLayoutConstraint(item: questionImgBox!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 100)
        
        let quiz = currentPage.quiz
        
        if quiz.question["text"] != nil && !quiz.question["text"]!.isEmpty {
            questionTxtVw.string = quiz.question["text"]!
        }
        
        if quiz.type == QuizTypes.FILL_IN_THE_BLANK || quiz.type == QuizTypes.SHORT_ANSWER {
            
            questionImgBox.isHidden = true
            
            view.removeConstraint(questionImgBoxWidthConstraint)
            view.addConstraint(NSLayoutConstraint(item: questionTxtVwScroller!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 640))
            
        } else {
            
            questionImgBox.isHidden = false

            view.addConstraint(questionImgBoxWidthConstraint)
            view.addConstraint(NSLayoutConstraint(item: questionTxtVwScroller!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 540))
            
            if quiz.question["image"] != nil && !quiz.question["image"]!.isEmpty {
                
                let image = currentDocument?.getAssetFileWrapper(name: quiz.question["image"]!, at: FileNames.IMAGES_DIR)
                questionImgBtn.image = NSImage(data: image!.regularFileContents!)
                
            }
            
        }
        
        refreshQuestionAudioState()

        setAnswerView()

    }

    @IBAction func setQuestionAudio(_ sender: NSButton) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }

        let sheet = QuizAudioViewController(title: "Question Audio",
                                            currentAudio: currentPage.quiz.question["audio"] ?? "",
                                            document: currentDocument) { [weak self] newAudio in
            currentPage.quiz.question["audio"] = newAudio
            self?.currentDocument?.updateChangeCount(.changeDone)
            self?.refreshQuestionAudioState()
        }

        presentAsSheet(sheet)

    }

    @IBAction func setQuestionImage(_ sender: NSButton) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }

        guard let url = Util.shared.browseForFile(allowedTypes: [FileExtensions.JPG, FileExtensions.JPEG, FileExtensions.PNG, FileExtensions.SVG]) else { return }

        let name = url.lastPathComponent
        currentDocument!.addAssetsWrappersFile(name: name, path: url, to: FileNames.IMAGES_DIR)
        currentPage.quiz.question["image"] = name
        currentDocument!.updateChangeCount(.changeDone)

        // refresh the preview thumbnail
        questionImgBtn.image = NSImage(contentsOf: url)

    }

    // Reflect the question's audio attachment in the trigger button's title.
    private func refreshQuestionAudioState() {

        guard currentDocument != nil,
              let currentPage = currentDocument?.currentXmlPage() else { return }

        let audio = currentPage.quiz.question["audio"] ?? ""
        if audio.isEmpty {
            questionAudioBtn?.title = "Question Audio…"
        } else {
            questionAudioBtn?.title = "Question Audio: " + (audio as NSString).lastPathComponent
        }

    }

    private func setAnswerView() {
        
        var childController: NSViewController?
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }
        
        // reset
        if childController != nil {
            childController = nil
        }
        
        for view in answerContainer.subviews {
            view.removeFromSuperview()
        }
        
        // set current quiz item
        
        let quiz = currentPage.quiz
        
        switch quiz.type {
            
        case QuizTypes.SHORT_ANSWER:
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.SHORT_ANSWER_VIEW) as! ShortAnswerViewController
            addChild(childController!)
            answerContainer.addSubview(childController!.view)
            
            (childController as! ShortAnswerViewController).currentDocument = currentDocument!
            (childController as! ShortAnswerViewController).display()
            
        case QuizTypes.FILL_IN_THE_BLANK:
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.FILL_IN_THE_BLANK_VIEW) as! FillInTheBlankViewController
            addChild(childController!)
            answerContainer.addSubview(childController!.view)
            
            (childController as! FillInTheBlankViewController).currentDocument = currentDocument!
            (childController as! FillInTheBlankViewController).display()
            
        case QuizTypes.MULTIPLE_CHOICE:
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.MULTIPLE_CHOICE_VIEW) as! MultipleChoiceViewController
            addChild(childController!)
            answerContainer.addSubview(childController!.view)
            
            (childController as! MultipleChoiceViewController).currentDocument = currentDocument!
            (childController as! MultipleChoiceViewController).display()
            
        case QuizTypes.MULTIPLE_ANSWER:
            
            childController = self.storyboard!.instantiateController(withIdentifier: PageViewIdentifiers.MULTIPLE_ANSWER_VIEW) as! MultipleAnswerViewController
            addChild(childController!)
            answerContainer.addSubview(childController!.view)
            
            (childController as! MultipleAnswerViewController).currentDocument = currentDocument!
            (childController as! MultipleAnswerViewController).display()
            
        default:
            break
        }
        
    }
    
    func textDidEndEditing(_ sender: Notification) {
        
        guard currentDocument != nil else { return }
        guard let textView = sender.object as? NSTextView else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }
        
        currentPage.quiz.question["text"] = textView.sanitize()
        currentDocument!.updateChangeCount(.changeDone)

    }

}

// MARK: - Quiz audio attach / preview sheet
//
// Reusable modal sheet for attaching, auditioning, and removing the audio on a quiz question or
// answer. Changes are applied only on "Done": a newly chosen file is copied into assets/audio/quiz/
// and the resulting attribute value ("quiz/<name>") is handed back through `completion`.

final class QuizAudioViewController: NSViewController, AVAudioPlayerDelegate {

    private let sheetTitle: String
    private let initialAudio: String
    private weak var document: Document?
    private let completion: (String) -> Void

    private var pendingURL: URL?          // a newly chosen file, not yet committed
    private var removed = false           // user asked to remove the existing clip
    private var player: AVAudioPlayer?

    private var fileField: NSTextField!
    private var previewBtn: NSButton!
    private var removeBtn: NSButton!

    init(title: String, currentAudio: String, document: Document?, completion: @escaping (String) -> Void) {
        self.sheetTitle = title
        self.initialAudio = currentAudio
        self.document = document
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 184))

        let titleLabel = NSTextField(labelWithString: sheetTitle)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.frame = NSRect(x: 20, y: 150, width: 360, height: 18)
        root.addSubview(titleLabel)

        fileField = NSTextField(labelWithString: "")
        fileField.textColor = .secondaryLabelColor
        fileField.lineBreakMode = .byTruncatingMiddle
        fileField.frame = NSRect(x: 20, y: 118, width: 360, height: 18)
        root.addSubview(fileField)

        let chooseBtn = NSButton(title: "Choose Audio…", target: self, action: #selector(choose))
        chooseBtn.bezelStyle = .rounded
        chooseBtn.frame = NSRect(x: 20, y: 72, width: 132, height: 30)
        root.addSubview(chooseBtn)

        previewBtn = NSButton(title: "▶ Preview", target: self, action: #selector(togglePreview))
        previewBtn.bezelStyle = .rounded
        previewBtn.frame = NSRect(x: 158, y: 72, width: 96, height: 30)
        root.addSubview(previewBtn)

        removeBtn = NSButton(title: "Remove Audio", target: self, action: #selector(removeAudio))
        removeBtn.bezelStyle = .rounded
        removeBtn.frame = NSRect(x: 260, y: 72, width: 120, height: 30)
        root.addSubview(removeBtn)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.frame = NSRect(x: 212, y: 20, width: 82, height: 30)
        root.addSubview(cancelBtn)

        let doneBtn = NSButton(title: "Done", target: self, action: #selector(done))
        doneBtn.bezelStyle = .rounded
        doneBtn.keyEquivalent = "\r"
        doneBtn.frame = NSRect(x: 298, y: 20, width: 82, height: 30)
        root.addSubview(doneBtn)

        self.view = root

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateState()
    }

    // The audio filename that "Done" would currently commit.
    private var effectiveName: String {
        if let url = pendingURL { return url.lastPathComponent }
        if removed { return "" }
        return (initialAudio as NSString).lastPathComponent
    }

    private var hasClip: Bool {
        return pendingURL != nil || (!removed && !initialAudio.isEmpty)
    }

    private func updateState() {
        let name = effectiveName
        fileField.stringValue = name.isEmpty ? "No audio attached" : name
        previewBtn.isEnabled = hasClip
        removeBtn.isEnabled = hasClip
    }

    @objc private func choose() {
        guard let url = Util.shared.browseForFile(allowedTypes: [FileExtensions.MP3]) else { return }
        stop()
        pendingURL = url
        removed = false
        updateState()
    }

    @objc private func removeAudio() {
        stop()
        pendingURL = nil
        removed = true
        updateState()
    }

    @objc private func togglePreview() {

        if player?.isPlaying == true { stop(); return }

        var data: Data?
        if let url = pendingURL {
            data = try? Data(contentsOf: url)
        } else if !removed, !initialAudio.isEmpty {
            data = document?.getAudioAssetWrapper(relativePath: initialAudio)?.regularFileContents
        }

        guard let clip = data else { return }

        do {
            player = try AVAudioPlayer(data: clip)
            player?.delegate = self
            player?.play()
            previewBtn.title = "■ Stop"
        } catch let error as NSError {
            NSLog(error.localizedDescription)
        }

    }

    private func stop() {
        player?.stop()
        player = nil
        previewBtn?.title = "▶ Preview"
    }

    @objc private func cancel() {
        stop()
        dismiss(self)
    }

    @objc private func done() {

        stop()

        var result = initialAudio
        if let url = pendingURL {
            result = document?.addQuizAudioFile(name: url.lastPathComponent, from: url) ?? initialAudio
        } else if removed {
            result = ""
        }

        completion(result)
        dismiss(self)

    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }

}

// MARK: - Shared per-row audio column for the multiple-choice / multiple-answer tables

enum QuizAudioColumn {

    private static let audioColumnWidth: CGFloat = 46

    // Append a fixed-width trailing "Audio" column, making the text columns flexible so it stays on screen.
    // The text columns are given an even share of the remaining width, are draggable, and remember the
    // widths the user picks under `autosaveName`.
    static func install(in table: NSTableView, autosaveName: String) {

        let id = NSUserInterfaceItemIdentifier(ObjIdentifiers.QUIZ_AUDIO_COL)
        guard table.tableColumn(withIdentifier: id) == nil else { return }

        // every column except the leading "correct" checkbox becomes flexible so the audio column fits
        let textColumns = Array(table.tableColumns.dropFirst())

        for col in textColumns {
            col.minWidth = 80
            col.maxWidth = 100_000
            col.resizingMask = [.autoresizingMask, .userResizingMask]
        }

        let audioCol = NSTableColumn(identifier: id)
        audioCol.title = "Audio"
        audioCol.width = audioColumnWidth
        audioCol.minWidth = audioColumnWidth
        audioCol.maxWidth = audioColumnWidth
        audioCol.resizingMask = []
        table.addTableColumn(audioCol)

        // Interface Builder hands Choices a much narrower default than Feedback; split the space evenly
        // instead. Uniform autoresizing then shares any extra window width between them rather than
        // dumping it all on the last column.
        let checkboxWidth = table.tableColumns.first?.width ?? 0
        let gutters = table.intercellSpacing.width * CGFloat(table.tableColumns.count)
        let available = table.bounds.width - checkboxWidth - audioColumnWidth - gutters

        if !textColumns.isEmpty, available > 0 {
            let share = available / CGFloat(textColumns.count)
            for col in textColumns {
                col.width = max(col.minWidth, share)
            }
        }

        table.allowsColumnResizing = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        // Applied last so any previously saved widths win over the defaults above.
        assignAutosaveIdentifiers(in: table)
        table.autosaveName = autosaveName
        table.autosaveTableColumns = true

        table.sizeToFit()

    }

    // Column autosaving keys off the column identifiers, so every column needs a stable, non-empty one.
    private static func assignAutosaveIdentifiers(in table: NSTableView) {

        for (i, col) in table.tableColumns.enumerated() where col.identifier.rawValue.isEmpty {
            col.identifier = NSUserInterfaceItemIdentifier("quizCol\(i)")
        }

    }

    // A borderless speaker/add button reflecting whether the row already has audio attached.
    static func button(hasAudio: Bool, target: AnyObject, action: Selector) -> NSButton {

        let button = NSButton()
        button.bezelStyle = .inline
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.image = NSImage(systemSymbolName: hasAudio ? "speaker.wave.2.fill" : "plus.circle",
                               accessibilityDescription: hasAudio ? "Has audio" : "No audio")
        button.contentTintColor = hasAudio ? NSColor.controlAccentColor : NSColor.tertiaryLabelColor
        button.toolTip = hasAudio ? "Edit answer audio" : "Add answer audio"
        button.target = target
        button.action = action
        return button

    }

}
