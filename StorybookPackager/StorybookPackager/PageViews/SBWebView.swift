//
//  SBWebView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/15/19.
//  Copyright © 2019 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa
import WebKit

/// A web view that stays out of the way of a file dragged over it.
///
/// WKWebView accepts a dropped file by navigating to it, which is never what a drop means here: the
/// web views in this app are previews of a slide, and a file dropped on one either belongs to the
/// slide it is previewing or belongs nowhere. Left registered, the preview would quietly replace
/// itself with whatever was dropped and the presentation would be none the wiser.
///
/// The sweep is repeated on every layout rather than done once, because WebKit builds its own
/// subviews out as a page loads and each one arrives registered for dropped files.
class NoDropWebView: WKWebView {

    override func layout() {
        super.layout()
        disableFileDrops()
    }

}

class SBWebView: NoDropWebView {
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NotificationCenter.default.post(name: Notification.Name("mouseOver"), object: self.window)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NotificationCenter.default.post(name: Notification.Name("mouseOut"), object: self.window)
    }
    
}
