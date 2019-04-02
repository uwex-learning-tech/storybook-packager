//
//  MultipleChoiceViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 4/2/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
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
        
    }
    
    @IBAction func deleteChoice(_ sender: NSButton) {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        guard choices != nil else { return }
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
        
        let newChoice: [String:String] = ["image":"", "audio":"", "value":"New choice", "feedback":"", "correct":""]
        
        choices!.append(newChoice)
        currentPage.quiz.choices = choices!
        currentDocument!.updateChangeCount(.changeDone)
        choicesTbl.reloadData()
        choicesTbl.editColumn(0, row: choicesTbl.numberOfRows - 1, with: nil, select: true)
        
    }
    
    @IBAction func choiceValueChange(_ sender: NSTextField) {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        guard choices != nil else { return }
        
        let index = choicesTbl.selectedRow
        
        if choices![index]["value"] != sender.stringValue {
            choices![index]["value"] = sender.stringValue
            currentPage.quiz.choices = choices!
            currentDocument!.updateChangeCount(.changeDone)
        }
        
    }
    
    @IBAction func feedbackChange(_ sender: NSTextField) {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        guard choices != nil else { return }
        
        let index = choicesTbl.selectedRow
        
        if choices![index]["feedback"] != sender.stringValue {
            choices![index]["feedback"] = sender.stringValue
            currentPage.quiz.choices = choices!
            currentDocument!.updateChangeCount(.changeDone)
        }
        
    }
    
    @IBAction func setCorrect(_ sender: NSButton) {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        guard choices != nil else { return }
        
        let index = choicesTbl.row(for: sender.superview!)
        
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
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
        if sender.state == .on {
            currentPage.quiz.random = true
        } else {
            currentPage.quiz.random = false
        }
        
        currentDocument!.updateChangeCount(.changeDone)
        
    }
    
    func display() {
        
        guard currentDocument != nil else { return }
        guard let currentPage = currentDocument?.getXmlObjPages()[(currentDocument?.currentPageIndex.first)!] else { return }
        
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
        
        if textView.identifier?.rawValue == "ma_correct" {
            currentPage.quiz.feedback.correct = textView.string
        } else if textView.identifier?.rawValue == "ma_incorrect" {
            currentPage.quiz.feedback.incorrect = textView.string
        }
        
        currentDocument!.updateChangeCount(.changeDone)
        
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
        
        if tableColumn == choicesTbl.tableColumns[0] {
            
            if let cell = choicesTbl.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ObjIdentifiers.MA_CHOICE_CELL), owner: nil ) as? NSTableCellView {
                
                let choice = choices![row]["value"]
                
                cell.textField?.stringValue = choice!
                
                return cell
                
            }
            
        }
        
        if tableColumn == choicesTbl.tableColumns[1] {
            
            if let cell = choicesTbl.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ObjIdentifiers.FEEDBACK_CELL), owner: nil ) as? NSTableCellView {
                
                let feedback = choices![row]["feedback"]
                
                cell.textField?.stringValue = feedback!
                
                return cell
                
            }
            
        }
        
        if tableColumn == choicesTbl.tableColumns[2] {
            
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
