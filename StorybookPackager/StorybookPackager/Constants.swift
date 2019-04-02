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
    static let ASSET_FILES = "Assets"
    static let PAGE = "Page"
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
    static let VTT = "vtt"
}

struct PageTypes {
    static let SECTION = "section"
    static let KALTURA = "kaltura"
    static let IMAGE = "image"
    static let IMAGE_AUDIO = "image-audio"
    static let YOUTUBE = "youtube"
    static let VIMEO = "vimeo"
    static let VIDEO = "video"
    static let BUNDLE = "bundle"
    static let QUIZ = "quiz"
    static let SHORT_ANSWER = "shortanswer"
    static let FILL_IN_THE_BLANK = "fillintheblank"
    static let MULTIPLE_CHOICE = "multiplechoice"
    static let MULTIPLE_ANSWER = "multipleanswer"
    static let HTML = "html"
}

struct QuizTypes {
    static let SHORT_ANSWER = "shortAnswer"
    static let FILL_IN_THE_BLANK = "fillInTheBlank"
    static let MULTIPLE_CHOICE = "multipleChoiceSingle"
    static let MULTIPLE_ANSWER = "multipleChoiceMultiple"
}

struct ObjIdentifiers {
    static let PROJECT_CELL = "projectCell"
    static let AUTHORS_COMBO_BOX = "authorsCombo"
    static let PAGE_IMAGE_PLACEHOLDER = "page-img-ph"
    static let SEGMENT_CELL = "SegmentCell"
    static let FRAME_CELL = "FrameCell"
    static let MA_CHOICE_CELL = "MAChoiceCell"
    static let MA_CORRECT_CELL = "MACorrectCell"
    static let FEEDBACK_CELL = "FeedbackCell"
}

struct WindowIdentifiers {
    static let STARTUP = "StartupWindow"
    static let PROJECT_WINDOW = "ProjectWindow"
    static let PROPERTIES_DIALOG = "PropertiesDialog"
    static let SETTINGS_DIALOG = "SettingsDialog"
    static let FILES_DIALOG = "FilesDialog"
}

struct PageViewIdentifiers {
    static let IMAGE_VIEW = "ImageView"
    static let IMAGE_AUDIO_VIEW = "ImageAudioView"
    static let BUNDLE_VIEW = "BundleView"
    static let VIDEO_VIEW = "VideoView"
    static let STREAMING_VIEW = "StreamingView"
    static let HTML_VIEW = "HtmlView"
    static let QUIZ_VIEW = "QuizView"
    static let NOTES_VIEW = "NotesView"
    static let WIDGETS_VIEW = "WidgetsView"
    static let SHORT_ANSWER_VIEW = "ShortAnswerView"
    static let FILL_IN_THE_BLANK_VIEW = "FillInTheBlankView"
    static let MULTIPLE_CHOICE_VIEW = "MultipleChoiceView"
    static let MULTIPLE_ANSWER_VIEW = "MultipleAnswerView"
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
    static let borderColor = NSColor.systemGray.cgColor
    static var borderColorSelected: CGColor = { () -> CGColor in
        
        if #available(OSX 10.14, *) {
            return NSColor.controlAccentColor.cgColor
        } else {
            return NSColor.systemBlue.cgColor
        }
        
    }()
    
}

struct Transition {
    static let NAMES: Array<String> = ["bounce", "flash", "pulse", "rubberBand", "shake", "swing", "tada", "wobble", "jello", "heartBeat", "bounceIn", "bounceInDown", "bounceInLeft", "bounceInRight", "bounceInUp", "bounceOut", "bounceOutDown", "bounceOutLeft", "bounceOutRight", "bounceOutUp", "fadeIn", "fadeInDown", "fadeInDownBig", "fadeInLeft", "fadeInLeftBig", "fadeInRight", "fadeInRightBig", "fadeInUp", "fadeInUpBig", "fadeOut", "fadeOutDown", "fadeOutDownBig", "fadeOutLeft", "fadeOutLeftBig", "fadeOutRight", "fadeOutRightBig", "fadeOutUp", "fadeOutUpBig", "flip", "flipInX", "flipInY", "flipOutX", "flipOutY", "lightSpeedIn", "lightSpeedOut", "rotateIn", "rotateInDownLeft", "rotateInDownRight", "rotateInUpLeft", "rotateInUpRight", "rotateOut", "rotateOutDownLeft", "rotateOutDownRight", "rotateOutUpLeft", "rotateOutUpRight", "slideInUp", "slideInDown", "slideInLeft", "slideInRight", "slideOutUp", "slideOutDown", "slideOutLeft", "slideOutRight", "zoomIn", "zoomInDown", "zoomInLeft", "zoomInRight", "zoomInUp", "zoomOut", "zoomOutDown", "zoomOutLeft", "zoomOutRight", "zoomOutUp", "hinge", "jackInTheBox", "rollIn", "rollOut"]
}


