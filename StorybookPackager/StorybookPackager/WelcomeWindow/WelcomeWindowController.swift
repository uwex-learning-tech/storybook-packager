//
//  WelcomeWindowController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/3/22.
//  Copyright © 2022 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class WelcomeWindowController: NSWindowController {

    // The size the two panels are drawn at in their XIBs. Neither XIB pins its root view's width or
    // height, so nothing but these numbers says how big the window should be — see windowDidLoad.
    private static let mainPanelWidth: CGFloat = 450
    private static let recentsPanelWidth: CGFloat = 300
    private static let panelHeight: CGFloat = 400

    override func windowDidLoad() {
        super.windowDidLoad()

        window?.isMovableByWindowBackground = true

        let splitViewController = WelcomeWindowSplitViewController()

        // Both panels are given a thickness explicitly. Their XIBs lay out under Auto Layout but
        // neither pins the root view's width, so the split view is free to size them to nothing —
        // and a split view holding two zero-width panels is a zero-width split view.
        let main = NSSplitViewItem(viewController: MainWelcomeViewController())
        main.minimumThickness = Self.mainPanelWidth
        main.maximumThickness = Self.mainPanelWidth
        main.canCollapse = false

        let recents = NSSplitViewItem(viewController: RecentsTableViewController(urls: NSDocumentController.shared.recentDocumentURLs))
        recents.minimumThickness = Self.recentsPanelWidth
        recents.canCollapse = false

        splitViewController.addSplitViewItem(main)
        splitViewController.addSplitViewItem(recents)

        contentViewController = splitViewController

        // Assigning contentViewController resizes the window to whatever the content asks for, and
        // with no height pinned anywhere that request can be nothing at all — which is how this
        // window came to open as an empty box a few points across. The size is stated here instead.
        window?.setContentSize(NSSize(width: Self.mainPanelWidth + Self.recentsPanelWidth,
                                      height: Self.panelHeight))
        window?.center()

    }
    
    convenience init() {
        self.init(windowNibName: NSNib.Name(String(describing: Self.self)))
    }
    
}
