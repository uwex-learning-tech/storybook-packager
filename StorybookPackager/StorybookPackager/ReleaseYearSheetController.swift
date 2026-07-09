//
//  ReleaseYearSheetController.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
//
//  Shown by Document.save(to:ofType:for:completionHandler:) when a presentation is about to be
//  written without a release year. Completion carries the chosen year, or nil when the user cancels
//  — which aborts the save entirely.
//

import Cocoa

final class ReleaseYearSheetController: NSViewController {

    private let currentYear: Int
    private let completion: (Int?) -> Void

    private var yearPopUp: NSPopUpButton!

    init(currentYear: Int, completion: @escaping (Int?) -> Void) {
        self.currentYear = currentYear
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 160))

        let titleLabel = NSTextField(labelWithString: "Choose a Release Year")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.frame = NSRect(x: 20, y: 122, width: 380, height: 18)
        root.addSubview(titleLabel)

        let infoLabel = NSTextField(wrappingLabelWithString: "This presentation doesn’t have a release year yet. Storybook+ uses it to locate the presentation’s splash image.")
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.isSelectable = false
        infoLabel.frame = NSRect(x: 20, y: 78, width: 380, height: 34)
        root.addSubview(infoLabel)

        let yearLabel = NSTextField(labelWithString: "Release Year")
        yearLabel.frame = NSRect(x: 20, y: 48, width: 90, height: 18)
        root.addSubview(yearLabel)

        yearPopUp = NSPopUpButton(frame: NSRect(x: 116, y: 42, width: 120, height: 25), pullsDown: false)
        yearPopUp.addItems(withTitles: ReleaseYear.titles)
        yearPopUp.selectItem(withTitle: String(currentYear))
        root.addSubview(yearPopUp)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.frame = NSRect(x: 226, y: 8, width: 82, height: 30)
        root.addSubview(cancelBtn)

        let setBtn = NSButton(title: "Set Year", target: self, action: #selector(setYear))
        setBtn.bezelStyle = .rounded
        setBtn.keyEquivalent = "\r"
        setBtn.frame = NSRect(x: 314, y: 8, width: 90, height: 30)
        root.addSubview(setBtn)

        self.view = root

    }

    @objc private func cancel() {
        dismiss(self)
        completion(nil)
    }

    @objc private func setYear() {

        let year = yearPopUp.titleOfSelectedItem.flatMap { Int($0) } ?? currentYear

        dismiss(self)
        completion(year)

    }

}
