//
//  ProjectWindowController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/10/18.
//  Copyright © 2018 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa
import Reachability

class ProjectWindowController: NSWindowController {
    
    @IBOutlet weak var windowToolbar: NSToolbar!
    @IBOutlet weak var noNetworkStatus: NSToolbarItem!
    @IBOutlet weak var touchBarDeleteBtn: NSButton!
    
    let reachability = try! Reachability()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        shouldCascadeWindows = true
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Close the Welcome window now a document has one. This asked the question of a freshly
        // constructed DocumentController rather than the shared one, whose hasOpenedDocument is
        // false by definition, so the window it was meant to dismiss stayed open behind the project.
        if ( (NSDocumentController.shared as? DocumentController)?.hasOpenedDocument ?? false ) {
            (NSApplication.shared.delegate as? AppDelegate)?.closeWelcomeWindowIfOpen()
        }
        
        // check for internet connetion
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
        
        do {
            try reachability.startNotifier()
        } catch {
            NSLog("could not start reachability notifier")
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.deleteBtnStateChanged), name: Notification.Name("deleteBtnStateChanged"), object: nil)
        
    }
    
    @objc func reachabilityChanged(note: Notification) {
        
        let reachability = note.object as! Reachability
        switch reachability.connection {
        case .unavailable:
            
            self.windowToolbar.insertItem(withItemIdentifier: NSToolbarItem.Identifier.init(rawValue: "noNetworkStatus"), at: self.windowToolbar.items.count)
            
        default:
            
            guard let lastIconIdentifier = self.windowToolbar.items.last?.itemIdentifier else { return }
            
            if (lastIconIdentifier.rawValue.isEqual("noNetworkStatus")) {
                self.windowToolbar.removeItem(at: self.windowToolbar.items.count - 1)
            }
            
        }
        
    }
    
    @objc func deleteBtnStateChanged(_ sender: Notification) {
        
        guard let userInfo = sender.userInfo else { return }
        
        if userInfo["enabled"] as! Bool {
            
            touchBarDeleteBtn.isEnabled = true
            touchBarDeleteBtn.state = .on
            
        } else {
            
            touchBarDeleteBtn.isEnabled = false
            touchBarDeleteBtn.state = .off
            
        }
        
    }
    
    func updateTitle(with: String) {
        self.window?.subtitle = with
    }

}
