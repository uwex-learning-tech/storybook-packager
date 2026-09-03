//
//  MultipleChoiceViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 4/2/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class MultipleChoiceViewController: NSViewController {

    @IBOutlet weak var randomizeBtn: NSButton!
    @IBOutlet weak var removeChoiceBtn: NSButton!
    @IBOutlet weak var choicesTbl: NSTableView!

    var currentDocument: Document?
    private var choices: Array<[String: String]>?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.

        choicesTbl.delegate = self
        choicesTbl.dataSource = self

        QuizAudioColumn.install(in: choicesTbl, autosaveName: "MultipleChoiceChoicesTable")

    }

    @IBAction func deleteChoice(_ sender: NSButton) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }
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
        guard let currentPage = currentDocument?.currentXmlPage() else { return }

        // Commit any in-flight cell edit before the row indices shift under it.
        view.window?.makeFirstResponder(nil)

        let newChoice: [String:String] = ["image":"", "audio":"", "value":"New choice", "feedback":"", "correct":""]

        choices!.append(newChoice)
        currentPage.quiz.choices = choices!
        currentDocument!.updateChangeCount(.changeDone)
        choicesTbl.reloadData()
        choicesTbl.editColumn(1, row: choicesTbl.numberOfRows - 1, with: nil, select: true)
        choicesTbl.selectRowIndexes([choicesTbl.numberOfRows - 1], byExtendingSelection: false)

    }

    @IBAction func choiceValueChange(_ sender: NSTextField) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }
        guard choices != nil else { return }

        // The row this field belongs to, not the selected one: they part company when the
        // selection moves while a cell is still being edited, and the text then lands on
        // another answer.
        guard let cell = sender.superview else { return }

        let index = choicesTbl.row(for: cell)
        let value = sender.sanitize()

        if choices!.indices.contains(index) {

            if choices![index]["value"] != value {
                choices![index]["value"] = value
                currentPage.quiz.choices = choices!
                currentDocument!.updateChangeCount(.changeDone)
            }

        }

    }

    @IBAction func feedbackChange(_ sender: NSTextField) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }
        guard choices != nil else { return }

        // The row this field belongs to, not the selected one: they part company when the
        // selection moves while a cell is still being edited, and the text then lands on
        // another answer.
        guard let cell = sender.superview else { return }

        let index = choicesTbl.row(for: cell)
        let feedback = sender.sanitize()

        if choices!.indices.contains(index) {

            if choices![index]["feedback"] != feedback {
                choices![index]["feedback"] = feedback
                currentPage.quiz.choices = choices!
                currentDocument!.updateChangeCount(.changeDone)
            }

        }

    }

    @IBAction func setCorrect(_ sender: NSButton) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }
        guard choices != nil else { return }

        // -1 for a cell no longer in the table: a reload underneath the click detaches the row
        // this checkbox sits in, and the click still arrives.
        guard let row = sender.superview,
              case let index = choicesTbl.row(for: row),
              choices!.indices.contains(index) else { return }

        for i in choices!.indices {
            choices![i]["correct"] = ""
        }

        if sender.state == .on {
            choices![index]["correct"] = "yes"
        } else {
            choices![index]["correct"] = ""
        }

        currentPage.quiz.choices = choices!
        choicesTbl.reloadData()
        currentDocument!.updateChangeCount(.changeDone)

    }

    @IBAction func toggleRandomize(_ sender: NSButton) {

        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.currentXmlPage() else { return }

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
        guard let currentPage = currentDocument?.currentXmlPage() else { return }
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
        guard let currentPage = currentDocument?.currentXmlPage() else { return }

        if currentPage.quiz.random {
            randomizeBtn.state = .on
        } else {
            randomizeBtn.state = .off
        }

        choices = currentPage.quiz.choices
        choicesTbl.reloadData()

    }

}

extension MultipleChoiceViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {

        guard choices != nil else { return 0 }
        return choices!.count

    }

}

extension MultipleChoiceViewController: NSTableViewDelegate {

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

        if tableColumn == choicesTbl.tableColumns[2] {

            if let cell = choicesTbl.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ObjIdentifiers.FEEDBACK_CELL), owner: nil ) as? NSTableCellView {

                if let feedback = choices![row]["feedback"] {
                    cell.textField?.stringValue = feedback
                }

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
