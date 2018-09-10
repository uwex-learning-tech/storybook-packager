//
//  SbXmlManager.swift
//  SbplusXMLManager
//
//  Created by Ethan Lin on 6/28/18.
//  Copyright © 2018 University of Wisconsin System Office of Academic and Student Affairs. All rights reserved.
//

import Foundation

public class SbXmlManager {
    
    var reader: SbXmlReader?
    
    public init() {}
    
    public func read( path: String ) throws -> String {
        
        var result: String = "";
        
        self.reader = SbXmlReader( path: path )
        try self.reader!.readXml()
        self.reader!.parseXml()
        
        #if os( OSX )
        
        let xml = try XMLDocument( xmlString: self.reader!.xmlString, options: XMLNode.Options.nodePreserveCDATA )
        result = xml.xmlString(options: .nodePrettyPrint)
        
        #elseif ( iOS )
        
        result = self.reader!.getXmlString()
        
        #endif
        
        return result
        
    }
    
    public func write( path: URL, content: String ) throws {
        
        #if os( OSX )
        
        let xml = try XMLDocument( xmlString: content, options: XMLNode.Options.nodePreserveCDATA )
        try xml.xmlString(options: [.nodeCompactEmptyElement, .nodePrettyPrint]).write( to: path, atomically: true, encoding: .utf8 )
        
        #endif
        
    }
    
}
