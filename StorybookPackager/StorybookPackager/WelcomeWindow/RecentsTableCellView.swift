//
//  RecentsProjectTableCellView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/7/22.
//  Copyright © 2022 University of Wisconsin System. All rights reserved.
//

import Cocoa

class RecentsTableCellView: NSTableCellView {

    @IBOutlet private weak var subtitleLbl: NSTextField!
    
    func configure(with url: URL) {
        
        imageView?.image = NSWorkspace.shared.icon(forFile: url.path)
        textField?.stringValue = url.deletingPathExtension().lastPathComponent
        subtitleLbl.stringValue = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        
    }
    
}
