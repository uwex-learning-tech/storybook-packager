//
//  ProjectWindowController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/10/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import Reachability

class ProjectWindowController: NSWindowController {
    
    @IBOutlet weak var windowTitleFld: NSTextField!
    @IBOutlet var accessoryView: NSView!
    
    let reachability = Reachability()!
    
    var accessoryViewController: NSTitlebarAccessoryViewController?
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        // load accessory view
        createAccessoryViewControllerIfNeeded()
        
        // check for internet connetion
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
        
        do {
            try reachability.startNotifier()
        } catch {
            print("could not start reachability notifier")
        }
        
    }
    
    @objc func reachabilityChanged(note: Notification) {
        
        let reachability = note.object as! Reachability
        
        switch reachability.connection {
        case .none:
            self.accessoryView.isHidden = false
        default:
            self.accessoryView.isHidden = true
        }
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        shouldCascadeWindows = true
    }
    
    func updateTitle(with: String) {
        windowTitleFld.stringValue = with
    }
    
    fileprivate func createAccessoryViewControllerIfNeeded() {
        
        guard self.accessoryViewController == nil else { return }

        let accessoryViewController = NSTitlebarAccessoryViewController()
        self.accessoryViewController = accessoryViewController
        accessoryViewController.view = accessoryView
        accessoryViewController.layoutAttribute = .right
        self.window?.addTitlebarAccessoryViewController(accessoryViewController)
        
    }

}
