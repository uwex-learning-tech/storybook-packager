//
//  DocumentController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/3/22.
//  Copyright © 2022 University of Wisconsin System. All rights reserved.
//

import Cocoa

class DocumentController: NSDocumentController {
    
    var hasOpenedDocument: Bool = false
    
    override func openDocument(withContentsOf url: URL, display displayDocument: Bool, completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        hasOpenedDocument = true
        super.openDocument(withContentsOf: url, display: displayDocument, completionHandler: completionHandler)
    }
    
    override func reopenDocument(for urlOrNil: URL?, withContentsOf contentsURL: URL, display displayDocument: Bool, completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        hasOpenedDocument = true
        super.reopenDocument(for: urlOrNil, withContentsOf: contentsURL, display: displayDocument, completionHandler: completionHandler)
    }

}
