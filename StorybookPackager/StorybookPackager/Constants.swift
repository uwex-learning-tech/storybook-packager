//
//  Constants.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 9/28/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Foundation

struct StoryboardIdentifiers {
    static let main = "Main"
}

struct SegueIdentifiers {
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
    static let borderColor = CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.75)
    static let borderColorSelected = CGColor(red: 0, green: 0.34509804, blue: 0.81568627, alpha: 1)
}
