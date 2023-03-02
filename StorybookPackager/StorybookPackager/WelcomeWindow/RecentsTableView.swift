//
//  RecentsTableView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/7/22.
//  Copyright © 2022 University of Wisconsin System. All rights reserved.
//

import Cocoa

class RecentsTableView: NSTableView {

    override func keyDown(with event: NSEvent) {
        if event.characters?.count == 1, event.keyCode == 36 {
            sendAction(doubleAction, to: target)
        } else {
            super.keyDown(with: event)
        }
    }
    
}
