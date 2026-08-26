//
//  WelcomeWindowSplitViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/3/22.
//  Copyright © 2022 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class WelcomeWindowSplitViewController: NSSplitViewController {

    override func loadView() {
        
        let splitView = SplitView()
        splitView.isVertical = true
        self.splitView = splitView
        super.loadView()
        
    }
    
    override func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        .zero
    }
    
}

final class SplitView: NSSplitView {
    
    override var dividerThickness: CGFloat {
        0
    }
    
}
