/**
 StorybookXmlClass.swift
 SbplusXMLManager
 
 This file contains public classes and structs that will serve as DTO for Storybook Plus XML data.
 
 Created by Ethan Lin on 6/27/18.
 Copyright © 2018 University of Wisconsin System Office of Academic and Student Affairs. All rights reserved.
*/

import Foundation

/// A Storybook Plus XML
public class StorybookXml {
    
    /// Variables to represent every elements in the XML
    var accent: String
    var pageImgFormat: String
    var splashImgFormat: String
    var analytics: Bool
    var mathJax: Bool
    var version: String
    var setup: Setup
    var sections: Array<Section>
    
    /**
     Initializes a new Storybook XML instance with full specification.
     
     - Parameters:
        - accent: the color accent
        - imgFormat: the page image format or file extension
        - splashFormat: the splash screen image format or file extension
        - analytics: enable or disable Google Analytics
        - mathJax: enable or disable MathJax
        - setup: a struct that contains presentation setup data
        - sections: an array of section struct which hold an array of page structs
        - xmlVersion: the version of the XML
     
     - Returns: A new Storybook XML instance.
     */
    public init( accent: String, imgFormat: String, splashFormat: String, analytics: Bool, mathJax: Bool, setup: Setup, sections: Array<Section>, xmlVersion: String ) {
        
        self.accent = accent
        self.pageImgFormat = imgFormat
        self.splashImgFormat = splashFormat
        self.analytics = analytics
        self.mathJax = mathJax
        self.setup = setup
        self.sections = sections
        self.version = xmlVersion
        
    }
    
    /**
     An alternative way to initialize a new Storybook XML instance with a partial specification.
     
     - Parameters:
        - accent: the color accent
        - imgFormat: the page image format or file extension
        - splashFormat: the splash screen image format or file extension
        - analytics: enable or disable Google Analytics
        - mathJax: enable or disable MathJax
        - xmlVersion: the version of the XML
     
     - Returns: A new Storybook XML instance with empty setup and section.
     */
    convenience public init( accent: String, imgFormat: String, splashFormat: String, analytics: Bool, mathJax: Bool, xmlVersion: String ) {
        
        self.init( accent: accent, imgFormat: imgFormat, splashFormat: splashFormat, analytics: analytics, mathJax: mathJax, setup: Setup(), sections: [], xmlVersion: xmlVersion )
        
    }
    
    /**
     Output the Storybook XML instance as a string.
     
     - Returns: A string contains all data in the Storybook XML instance.
     */
    public func toString() -> String {
        
        let string = """
                     <?xml version="1.0" encoding="UTF-8" ?>
                     <storybook accent="\(self.accent)" pageImgFormat="\(self.pageImgFormat)" splashImgFormat="\(self.splashImgFormat)" analytics="\(self.analytics.description)" mathjax="\(self.mathJax.description)" xmlVersion="\(self.version)">
                         <setup program="\(self.setup.program)" course="\(self.setup.course)">
                             <title>\(self.setup.title)</title>
                             <subtitle>\(self.setup.subtitle)</subtitle>
                             <length>\(self.setup.length)</length>
                             <author name="\(self.setup.authorName)"><![CDATA[\(self.setup.authorProfile)]]></author>
                             <generalInfo><![CDATA[\(self.setup.generalInfo)]]></generalInfo>
                         </setup>
                         \(self.getSectionString())
                     </storybook>
                     """
        
        return string
        
    }
    
    /**
     Obtain data in the sections array as a string.
     
     - Returns: A string contains all page data of all sections in the Storybook XML instance.
     */
    public func getSectionString() -> String {
        
        var sectionString: String = ""
        var count = 0;
        
        /// loop through section
        for section in self.sections {
            
            count += 1
            sectionString += "<section title=\"\(section.title)>\""
            
            /// loop through pages within a section
            for page in section.pages {
                
                sectionString += "<page type=\"\(page.type)\" src=\"\(page.src)\" title=\"\(page.title)\" transition=\"\(page.transition)\" embed=\"\(page.embed)\">"
                
                /// loop through segments within a page
                if ( page.widget.count > 0 ) {
                    
                    sectionString += "<widget>"
                    
                    for segment in page.widget {
                        
                        sectionString += "<segment name=\"\(segment.name)\"><![CDATA[\(segment.content)]]></segment>"
                        
                    }
                    
                    sectionString += "</widget>"
                    
                }
                
                /// loop through frames within a page
                
                if ( page.frames.count > 0 ) {
                    
                    for frame in page.frames {
                        
                        sectionString += "<frame start=\"\(frame)\" />"
                        
                    }
                    
                }
                
                // get quiz item if quiz type
                if ( page.type == "quiz" ) {
                    
                    sectionString += page.quiz.generateXML()
                    
                } else {
                    
                    sectionString += "<note>\(page.notes)</note>"
                    
                }
                
                // get audio if it is html
                if( page.type == "html" && !page.audio.isEmpty ) {
                    
                    sectionString += "<audio src=\"\(page.audio)\" />"
                    
                }
                
                sectionString += "</page>"
                
            }
            
            sectionString += "</section>"
            
        }
        
        return sectionString
        
    }
    
    /**
     Add setup information to the Storybook XML instance.
     
     - Parameter setup: The setup struct to be set.
     */
    public func setSetup( setup: Setup ) {
        
        self.setup = setup
        
    }
    
    /**
     Add a section to the sections array of the Storybook XML instance
     
     - Parameter section: The section struct to be added.
     */
    public func addSection( section: Section ) {
        
        self.sections.append( section )
        
    }
    
}

// A setup element in a Storybook Plus XML
public struct Setup {
    
    private var _program: String = ""
    private var _course:String = ""
    private var _title:String = ""
    private var _subtitle:String = ""
    private var _length: String = ""
    private var _authorName:String = ""
    private var _authorProfile:String = ""
    private var _generalInfo:String = ""
    
    var program: String {
        
        get {
            
            return self._program
            
        }
        
        set {
            
            self._program = newValue
            
        }
        
    }
    
    var course: String {
        
        get {
            
            return self._course
            
        }
        
        set {
            
            self._course = newValue
            
        }
        
    }
    var title: String {
        
        get {
            
            return self._title
            
        }
        
        set {
            
            self._title = newValue
            
        }
        
    }
    
    var subtitle: String {
        
        get {
            
            return self._subtitle
            
        }
        
        set {
            
            self._subtitle = newValue
            
        }
        
    }
    
    var length: String {
        
        get {
            
            return self._length
            
        }
        
        set {
            
            self._length = newValue
            
        }
        
    }
    
    var authorName: String {
        
        get {
            
            return self._authorName
            
        }
        
        set {
            
            self._authorName = newValue
            
        }
        
    }
    
    var authorProfile: String {
        
        get {
            
            return self._authorProfile
            
        }
        
        set {
            
            self._authorProfile = newValue
            
        }
        
    }
    
    var generalInfo: String {
        
        get {
            
            return self._generalInfo
            
        }
        
        set {
            
            self._generalInfo = newValue
            
        }
        
    }
    
}

/// A section element in a Storybook Plus XML
public struct Section {
    
    private var _title: String = ""
    private var _pages: Array<Page> = []
    
    var title: String {
        
        get {
            
            return self._title
            
        }
        
        set {
            
            self._title = newValue
            
        }
        
    }
    
    var pages: Array<Page> {
        
        get {
            
            return self._pages
            
        }
        
        set {
            
            self._pages = newValue
            
        }
        
    }
    
}

// a page element in a Storybook XML
public class Page {
    
    private var _type: String = ""
    private var _src: String = ""
    private var _title: String = ""
    private var _transition: String = ""
    private var _embed: Bool = false
    private var _notes: String = ""
    private var _widget: Array<Segment> = []
    private var _frames: Array<String> = []
    private var _quiz: QuizItem = QuizItem( type: "" )
    private var _audio: String = ""
    
    var type: String {
        
        get {
            
            return self._type
            
        }
        
        set {
            
            self._type = newValue
            
        }
        
    }
    
    var src: String {
        
        get {
            
            return self._src
            
        }
        
        set {
            
            self._src = newValue
            
        }
        
    }
    
    var title: String {
        
        get {
            
            return self._title
            
        }
        
        set {
            
            self._title = newValue
            
        }
        
    }
    
    var transition: String {
        
        get {
            
            return self._transition
            
        }
        
        set {
            
            self._transition = newValue
            
        }
        
    }
    
    var embed: Bool {
        
        get {
            
            return self._embed
            
        }
        
        set {
            
            self._embed = newValue
            
        }
        
    }
    
    var notes: String {
        
        get {
            
            return self._notes
            
        }
        
        set {
            
            self._notes = newValue
            
        }
        
    }
    
    var widget: Array<Segment> {
        
        get {
            
            return self._widget
            
        }
        
    }
    
    var frames: Array<String> {
        
        get {
            
            return self._frames
            
        }
        
    }
    
    var quiz: QuizItem {
        
        get {
            
            return self._quiz
            
        }
        
        set {
            
            self._quiz = newValue
            
        }
        
    }
    
    var audio: String {
        
        get {
            
            return self._audio
            
        }
        
        set {
            
            self._audio = newValue
            
        }
        
    }
    
    // an empty init for flexibility
    public init() {}
    
    /**
     Add a segment to the segments array of a page instance.
     
     - Parameter segment: the segment struct to be added.
     */
    public func addSegment( segment: Segment ) {
        
        self._widget.append( segment )
        
    }
    
    /**
     Add a frame to the frames array of a page instance.
     
     - Parameter frame: the frame timecode to be added.
     */
    public func addFrame( frame: String ) {
        
        self._frames.append( frame )
        
    }
    
}

// A segment of a widget in a page element of a Storybook Plus XML
public struct Segment {
    
    private var _name: String = ""
    private var _content: String = ""
    
    var name: String {
        
        get {
            
            return self._name
            
        }
        
        set {
            
            self._name = newValue
            
        }
        
    }
    
    var content: String {
        
        get {
            
            return self._content
            
        }
        
        set {
            
            self._content = newValue
            
        }
        
    }
    
}

// structs to hold related quiz elements for Storybook Plus page

public class QuizItem {
    
    private var _question: [String: String] = [:]
    private var _type: String = ""
    private var _feedback: Feedback = Feedback()
    private var _choices: Array<[String: String]> = []
    private var _random: Bool = false
    private var _answer: String = ""
    
    var question: [String: String] {
        
        get {
            
            return self._question
            
        }
        
        set {
            
            self._question = newValue
            
        }
        
    }
    
    var type: String {
        
        get {
            
            return self._type
            
        }
        
    }
    
    var feedback: Feedback {
        
        get {
            
            return self._feedback;
            
        }
        
        set {
            
            self._feedback = newValue
            
        }
        
    }
    
    var choices: Array<[String: String]> {
        
        get {
            
            return self._choices
            
        }
        
        set {
            
            self._choices = newValue
            
        }
        
    }
    
    var random: Bool {
        
        get {
            
            return self._random
            
        }
        
        set {
            
            self._random = newValue
            
        }
        
    }
    
    var answer: String {
        
        get {
            
            return self._answer
            
        }
        
        set {
            
            self._answer = newValue
            
        }
        
    }
    
    public init( type: String ) {
        
        self._type = type
        
    }
    
    func generateXML() -> String {
        return ""
    }
    
}

public class ShortAnswer: QuizItem {
    
    public init() {
        
        super.init(type: "shortAnswer")
        
    }
    
    override public func generateXML() -> String {
        
        return "<shortAnswer><question image=\"\(self.question["image"]!)\" audio=\"\(self.question["audio"]!)\"><![CDATA[\(self.question["text"]!)]]></question><feedback><![CDATA[\(self.feedback.simple)]]></feedback></shortAnswer>"
        
    }
    
}

public class FillInTheBlank: QuizItem {
    
    public init() {
        
        super.init( type: "fillInTheBlank" )
        
    }
    
    override public func generateXML() -> String {
        
        return "<fillInTheBlank><question image=\"\(self.question["image"]!)\" audio=\"\(self.question["audio"]!)\"><![CDATA[\(self.question["text"]!)]]></question><answer>\(self.answer)</answer><correctFeedback><![CDATA[\(self.feedback.correct)]]></correctFeedback><![CDATA[\(self.feedback.incorrect)]]><incorrectFeedback></incorrectFeedback></fillInTheBlank>"
        
    }
    
}

public class MultipleChoiceSingle: QuizItem {
    
    public init() {
        
        super.init( type: "multipleChoiceSingle" )
        
    }
    
    override public func generateXML() -> String {
        
        var xml = "<multipleChoiceSingle><question image=\"\(self.question["image"]!)\" audio=\"\(self.question["audio"]!)\"><![CDATA[\(self.question["text"]!)]]></question><choices random=\"\(self.random)\">"
        
        for answer in self.choices {
            
            xml += "<answer image=\"\(answer["image"] ?? "")\" audio=\"\(answer["audio"] ?? "")\" correct=\"\(answer["correct"] ?? "")\"><value>\(answer["value"] ?? "")</value><feedback><![CDATA[\(answer["feedback"] ?? "")]]></feedback></answer>"
            
        }
        
        xml += "</choices></multipleChoiceSingle>"
        
        return xml
        
    }
    
}

public class MultipleChoiceMultiple: QuizItem {
    
    public init() {
        
        super.init( type: "multipleChoiceMultiple" )
        
    }
    
    override public func generateXML() -> String {
        
        var xml = "<multipleChoiceSingle><question image=\"\(self.question["image"]!)\" audio=\"\(self.question["audio"]!)\"><![CDATA[\(self.question["text"]!)]]></question><choices random=\"\(self.random)\">"
        
        for answer in self.choices {
            
            xml += "<answer image=\"\(answer["image"] ?? "")\" audio=\"\(answer["audio"] ?? "")\" correct=\"\(answer["correct"] ?? "")\"><value>\(answer["value"] ?? "")</value></answer>"
            
        }
        
        xml += "</choices><correctFeedback><![CDATA[\(self.feedback.correct)]]></correctFeedback><incorrectFeedback><![CDATA[\(self.feedback.incorrect)]]>)</incorrectFeedback></multipleChoiceSingle>"
        
        return xml
        
    }
    
}

public struct Feedback {
    
    private var _simple: String = ""
    private var _correct: String = ""
    private var _incorrect: String = ""
    
    var simple: String {
        
        get {
            
            return self._simple
            
        }
        
        set {
            
            self._simple = newValue
            
        }
        
    }
    
    var correct: String {
        
        get {
            
            return self._correct
            
        }
        
        set {
            
            self._correct = newValue
            
        }
        
    }
    
    var incorrect: String {
        
        get {
            
            return self._incorrect
            
        }
        
        set {
            
            self._incorrect = newValue
            
        }
        
    }
    
}
