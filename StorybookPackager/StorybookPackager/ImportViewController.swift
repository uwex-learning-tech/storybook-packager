//
//  ImportViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 2/28/19.
//  Copyright © 2019 University of Wisconsin System. All rights reserved.
//

import Cocoa

class ImportViewController: NSViewController {

    @IBOutlet weak var importingProgress: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        importingProgress.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(self.progressStarted), name: Notification.Name("importStarted"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.progressDone), name: Notification.Name("importCompleted"), object: nil)
    }
    
    @IBAction func dismissDialog(_ sender: NSButton) {
        self.dismiss(self)
    }
    
    @objc func progressStarted(_ sender: Notification) {
        importingProgress.isHidden = false
    }
    
    @objc func progressDone(_ sender: Notification) {
        importingProgress.isHidden = true
    }
    
}
