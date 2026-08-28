//
//  RecentsProjectTableCellView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/7/22.
//  Copyright © 2022 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class RecentsTableCellView: NSTableCellView {

    @IBOutlet private weak var subtitleLbl: NSTextField!
    
    func configure(with url: URL) {
        
        imageView?.image = NSWorkspace.shared.icon(forFile: url.path)
        textField?.stringValue = url.deletingPathExtension().lastPathComponent
        subtitleLbl.stringValue = RecentProjects.location(for: url)

        // Nothing is lost by shortening the line above: the path in full is a hover away.
        toolTip = (url.path as NSString).abbreviatingWithTildeInPath
        
    }
    
}
