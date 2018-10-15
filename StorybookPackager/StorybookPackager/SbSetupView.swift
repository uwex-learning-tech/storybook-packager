//
//  SbSetupView.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 10/9/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class SbSetupView: NSView {

    @IBOutlet var contentView: NSView!
    
//    override func draw(_ dirtyRect: NSRect) {
//        super.draw(dirtyRect)
//
//        // Drawing code here.
//    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        commonInit()
    }
    
    private func commonInit() {
        Bundle.main.loadNibNamed(ViewIdentifiers.setupView, owner: self, topLevelObjects: nil)

        addSubview(contentView)
        contentView.frame = self.bounds

        contentView.autoresizingMask = [.width]
        
    }
    
}
