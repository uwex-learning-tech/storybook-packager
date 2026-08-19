//
//  ReleaseYearSheetController.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  Shown by Document.save(to:ofType:for:completionHandler:) when a presentation is about to be
//  written without a release year. The year is required, so the sheet has no way out but to pick
//  one — it opens on the current year, which is the sensible default.
//

import Cocoa

final class ReleaseYearSheetController: NSViewController {

    private let currentYear: Int
    private let completion: (Int) -> Void

    private var yearPopUp: NSPopUpButton!

    init(currentYear: Int, completion: @escaping (Int) -> Void) {
        self.currentYear = currentYear
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 142))

        let titleLabel = NSTextField(labelWithString: "Choose a Release Year")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.frame = NSRect(x: 20, y: 104, width: 380, height: 18)
        root.addSubview(titleLabel)

        let infoLabel = NSTextField(wrappingLabelWithString: "This presentation doesn’t have a release year yet. One is required.")
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.isSelectable = false
        infoLabel.frame = NSRect(x: 20, y: 78, width: 380, height: 18)
        root.addSubview(infoLabel)

        let yearLabel = NSTextField(labelWithString: "Release Year")
        yearLabel.frame = NSRect(x: 20, y: 48, width: 90, height: 18)
        root.addSubview(yearLabel)

        yearPopUp = NSPopUpButton(frame: NSRect(x: 116, y: 42, width: 120, height: 25), pullsDown: false)
        yearPopUp.addItems(withTitles: ReleaseYear.titles)
        yearPopUp.selectItem(withTitle: String(currentYear))
        root.addSubview(yearPopUp)

        let setBtn = NSButton(title: "Set Year", target: self, action: #selector(setYear))
        setBtn.bezelStyle = .rounded
        setBtn.keyEquivalent = "\r"
        setBtn.frame = NSRect(x: 314, y: 8, width: 90, height: 30)
        root.addSubview(setBtn)

        self.view = root

    }

    @objc private func setYear() {

        let year = yearPopUp.titleOfSelectedItem.flatMap { Int($0) } ?? currentYear

        dismiss(self)

        // Next runloop turn: the sheet is only actually detached from the window after this one, and
        // the save this kicks off checks for an attached sheet to decide whether it can write in the
        // background. Called inline, every new presentation's first save would be a synchronous one
        // with no progress sheet — a beachball where the bar should be.
        DispatchQueue.main.async {
            self.completion(year)
        }

    }

}
