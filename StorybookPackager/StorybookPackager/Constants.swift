//
//  Constants.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 9/28/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Foundation
import Cocoa

struct StoryboardIdentifiers {
    static let main = "Main"
}

struct WindowIdentifiers {
    static let START = "StartWindow"
    static let PROJECT_WINDOW = "ProjectWindow"
    static let PROPERTIES_DIALOG = "PropertiesDialog"
    static let SETTINGS_DIALOG = "SettingsDialog"
}

struct CellIdentifiers {
    static let project = "projectCell"
}

struct FileIdentifiers {
    static let recentProject = "sbprojrecent"
    static let sbxml = "sbplus"
}

struct FileTypeIndentifiers {
    static let xml = "xml"
    static let json = "json"
}

struct PageCell {
    
    static let borderWidth = CGFloat(integerLiteral: 1)
    static let borderWidthSelected = CGFloat(integerLiteral: 2)
    static let borderColor = NSColor.darkGray.cgColor
    static var borderColorSelected: CGColor = { () -> CGColor in
        
        if #available(OSX 10.14, *) {
            return NSColor.controlAccentColor.cgColor
        } else {
            return NSColor.systemBlue.cgColor
        }
        
    }()
    
}

struct XML {
    static let emptyString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><storybook></storybook>"
}
