//
//  Constants.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 9/28/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Foundation
import Cocoa

struct StoryboardNames {
    static let STARTUP = "Startup"
    static let PREFERENCES = "Preferences"
    static let MAIN = "Main"
}

struct FileNames {
    static let ASSET_DIR = "assets"
    static let SB_HTML_FILE = "index.html"
    static let XML_FILE = "sbplus.xml"
    static let PAGES_DIR = "pages"
    static let AUDIO_DIR = "audio"
    static let VIDEO_DIR = "video"
    static let HTML_DIR = "html"
    static let IMAGES_DIR = "images"
}

struct FileExtensions {
    static let JSON = "json"
    static let HTML = "html"
    static let JPG = "jpg"
    static let SVG = "svg"
    static let PNG = "png"
    static let MP3 = "mp3"
    static let MP4 = "mp4"
    static let PDF = "pdf"
    static let ZIP = "zip"
}

struct PageTypes {
    static let SECTION = "section"
    static let KALTURA = "kaltura"
    static let IMAGE = "image"
    static let IMAGE_AUDIO = "image-audio"
    static let YOUTUBE = "youtube"
    static let VIMEO = "vimeo"
    static let VIDEO = "video"
}

struct Xibs {
    static let PAGE_VIEW_ITEM = "PageViewItem"
    static let PAGE_SECTION_ITEM = "PageSectionItem"
    static let SECTION_VIEW_ITEM = "SectionViewItem"
    static let KALTURA_VIEW_ITEM = "KalturaViewItem"
    static let IMAGE_VIEW_ITEM = "ImageViewItem"
    static let IMAGE_AUDIO_VIEW_ITEM = "ImageAudioViewItem"
    static let YOUTUBE_VIEW_ITEM = "YoutubeViewItem"
    static let VIMEO_VIEW_ITEM = "VimeoViewItem"
    static let VIDEO_VIEW_ITEM = "VideoViewItem"
    static let EMPTY = "EmptyViewItem"
}

struct ObjIdentifiers {
    static let PAGE_COLLECTION = "pages"
    static let PROJECT_CELL = "projectCell"
    static let AUTHORS_COMBO_BOX = "authorsCombo"
    static let PAGE_IMAGE_PLACEHOLDER = "page-img-ph"
}

struct WindowIdentifiers {
    static let STARTUP = "StartupWindow"
    static let PROJECT_WINDOW = "ProjectWindow"
    static let PROPERTIES_DIALOG = "PropertiesDialog"
    static let SETTINGS_DIALOG = "SettingsDialog"
}

struct Preferences {
    static let ASSET_FILE_NAME = "assetFileName"
    static let PAGE_TYPE = "pageType"
    static let SPLASH_IMG_FORMAT = "splashImgFormat"
    static let PAGE_IMG_FORMAT = "pageImgFormat"
    static let NUM_OF_SECTIONS = "numSections"
    static let NUM_OF_PAGES = "numPages"
    static let KALTURA_PARTNER_ID = "kalturaPartnerId"
    static let KALTURA_FLAVOR_ID = "kalturaFlavorId"
    static let PROGRAM_SRC = "programSrc"
    static let AUTHOR_SRC = "authorSrc"
    static let AUTHOR_REPO = "authorProfileRepo"
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


