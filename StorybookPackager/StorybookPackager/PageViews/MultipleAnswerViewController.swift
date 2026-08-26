//
//  MultipleAnswerViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/29/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class MultipleAnswerViewController: NSViewController, NSTextViewDelegate {

    @IBOutlet weak var randomizeBtn: NSButton!
    @IBOutlet var correctFdbckTxtVw: NSTextView!
    @IBOutlet var incorrectFdbckTxtVw: NSTextView!
    @IBOutlet weak var removeChoiceBtn: NSButton!
    @IBOutlet weak var choicesTbl: NSTableView!

    var currentDocument: Document?
    private var choices: Array<[String: String]>?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        correctFdbckTxtVw.isAutomaticQuoteSubstitutionEnabled = false
        correctFdbckTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        correctFdbckTxtVw.delegate = self

        incorrectFdbckTxtVw.isAutomaticQuoteSubstitutionEnabled = false
        incorrectFdbckTxtVw.textContainerInset = NSSize(width: 5, height: 8)
        incorrectFdbckTxtVw.delegate = self

        choicesTbl.delegate = self
        choicesTbl.dataSource = self

        QuizAudioColumn.install(in: choicesTbl, autosaveName: "MultipleAnswerChoicesTable")

    }

    @IBAction func deleteChoice(_ sender: NSButton) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        guard choices != nil else { return }

        // Commit any in-flight cell edit before the row indices shift under it.
        view.window?.makeFirstResponder(nil)

        guard let index = choicesTbl.selectedRowIndexes.first else { return }

        if choices!.indices.contains(index) {
            choices!.remove(at: index)
            currentPage.quiz.choices = choices!
            currentDocument!.updateChangeCount(.changeDone)
            choicesTbl.reloadData()
        }

    }

    @IBAction func addChoice(_ sender: NSButton) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }

        // Commit any in-flight cell edit before the row indices shift under it.
        view.window?.makeFirstResponder(nil)

        let newChoice: [String:String] = ["image":"", "audio":"", "value":"New choice", "correct":""]

        choices!.append(newChoice)
        currentPage.quiz.choices = choices!
        currentDocument!.updateChangeCount(.changeDone)
        choicesTbl.reloadData()
        choicesTbl.editColumn(1, row: choicesTbl.numberOfRows - 1, with: nil, select: true)
        choicesTbl.selectRowIndexes([choicesTbl.numberOfRows - 1], byExtendingSelection: false)

    }

    @IBAction func choiceValueChange(_ sender: NSTextField) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        guard choices != nil else { return }

        let index = choicesTbl.selectedRow
        let value = sender.sanitize()

        if choices!.indices.contains(index) {

            if choices![index]["value"] != value {
                choices![index]["value"] = value
                currentPage.quiz.choices = choices!
                currentDocument!.updateChangeCount(.changeDone)
            }

        }

    }

    @IBAction func setCorrect(_ sender: NSButton) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        guard choices != nil else { return }

        let index = choicesTbl.row(for: sender.superview!)

        if sender.state == .on {
            choices![index]["correct"] = "yes"
        } else {
            choices![index]["correct"] = ""
        }

        currentPage.quiz.choices = choices!
        currentDocument!.updateChangeCount(.changeDone)

    }

    @IBAction func toggleRandomize(_ sender: NSButton) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }

        if sender.state == .on {
            currentPage.quiz.random = true
        } else {
            currentPage.quiz.random = false
        }

        currentDocument!.updateChangeCount(.changeDone)

    }

    // Open the shared attach/preview sheet for the answer whose audio button was clicked.
    @objc func rowAudioClicked(_ sender: NSButton) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        guard choices != nil else { return }

        let row = choicesTbl.row(for: sender)
        guard choices!.indices.contains(row) else { return }

        let sheet = QuizAudioViewController(title: "Answer Audio",
                                            currentAudio: choices![row]["audio"] ?? "",
                                            document: currentDocument) { [weak self] newAudio in
            guard let self = self, self.choices != nil, self.choices!.indices.contains(row) else { return }
            self.choices![row]["audio"] = newAudio
            currentPage.quiz.choices = self.choices!
            self.currentDocument?.updateChangeCount(.changeDone)
            self.choicesTbl.reloadData()
        }

        presentAsSheet(sheet)

    }

    func display() {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }

        correctFdbckTxtVw.string = currentPage.quiz.feedback.correct
        incorrectFdbckTxtVw.string = currentPage.quiz.feedback.incorrect

        if currentPage.quiz.random {
            randomizeBtn.state = .on
        } else {
            randomizeBtn.state = .off
        }

        choices = currentPage.quiz.choices
        choicesTbl.reloadData()

    }

    func textDidEndEditing(_ sender: Notification) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        guard let textView = sender.object as? NSTextView else { return }

        let feedback = textView.sanitize()

        if textView.identifier?.rawValue == "ma_correct" {
            currentPage.quiz.feedback.correct = feedback
        } else if textView.identifier?.rawValue == "ma_incorrect" {
            currentPage.quiz.feedback.incorrect = feedback
        }

        currentDocument!.updateChangeCount(.changeDone)

    }

}

extension MultipleAnswerViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {

        guard choices != nil else { return 0 }
        return choices!.count

    }

}

extension MultipleAnswerViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        guard choices != nil else { return nil }

        if tableColumn?.identifier.rawValue == ObjIdentifiers.QUIZ_AUDIO_COL {
            return QuizAudioColumn.button(hasAudio: !(choices![row]["audio"] ?? "").isEmpty,
                                          target: self, action: #selector(rowAudioClicked(_:)))
        }

        if tableColumn == choicesTbl.tableColumns[0] {

            if let cell = choicesTbl.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ObjIdentifiers.MA_CORRECT_CELL), owner: nil ) as? CorrectTabelCellView {

                let correct = choices![row]["correct"]?.lowercased()

                if correct != "yes" && correct != "true" {
                    cell.correctBtn.state = .off
                } else {
                    cell.correctBtn.state = .on
                }

                return cell

            }

        }

        if tableColumn == choicesTbl.tableColumns[1] {

            if let cell = choicesTbl.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ObjIdentifiers.MA_CHOICE_CELL), owner: nil ) as? NSTableCellView {

                let choice = choices![row]["value"]

                cell.textField?.stringValue = choice!

                return cell

            }

        }

        return nil

    }

    func tableViewSelectionDidChange(_ notification: Notification) {

        if choicesTbl.selectedRowIndexes.count >= 1 {
            removeChoiceBtn.isEnabled = true
        } else {
            removeChoiceBtn.isEnabled = false
        }

    }

}
