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
    static let start = "StartWindow"
    static let presentation = "PresentationWindow"
    static let newPresentation = "NewPresentationDialog"
}

struct ViewIdentifiers {
    static let setupView = "SbSetupView"
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

struct MaxLimit {
    static let recentProject = 10
}

struct PageCell {
    static let borderWidth = CGFloat(integerLiteral: 1)
    static let borderWidthSelected = CGFloat(integerLiteral: 2)
    static let borderColor = NSColor.darkGray.cgColor
    static let borderColorSelected = NSColor.systemBlue.cgColor
}

struct XML {
    static let emptyString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><storybook></storybook>"
}
