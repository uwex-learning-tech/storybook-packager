//
//  PropertiesDialogController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/10/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class PropertiesDialogController: NSViewController {

    var completionHandler: ((PresentationProperties) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
    }
    
    @IBAction func savePropertiesDialog(_ sender: NSButton) {
        
        var properties = PresentationProperties()
        
        properties.completed = true
        
        self.completionHandler?(properties)
        
    }
    
    @IBAction func cancelPropertiesDialog(_ sender: NSButton) {
        
        let properties = PresentationProperties()
        self.completionHandler?(properties)
        
    }
    
}

struct PresentationProperties {
    var completed: Bool = false
}
