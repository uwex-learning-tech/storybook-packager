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
    @IBOutlet weak var touchBarDeleteBtn: NSButton!
    @IBOutlet weak var touchBarConfirmTitleBtn: NSButton!
    
    let reachability = try! Reachability()
    var accessoryViewController: NSTitlebarAccessoryViewController?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        shouldCascadeWindows = true
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        accessoryView.isHidden = true
        
        // load accessory view
        createAccessoryViewControllerIfNeeded()
        
        // check for internet connetion
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
        
        do {
            try reachability.startNotifier()
        } catch {
            NSLog("could not start reachability notifier")
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.deleteBtnStateChanged), name: Notification.Name("deleteBtnStateChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.confirmTitleBtnStateChanged), name: Notification.Name("confirmTitleBtnStateChanged"), object: nil)
        
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
    
    @objc func deleteBtnStateChanged(_ sender: Notification) {
        
        guard let userInfo = sender.userInfo else { return }
        
        if userInfo["enabled"] as! Bool {
            
            touchBarDeleteBtn.isEnabled = true
            touchBarDeleteBtn.state = .on
            touchBarDeleteBtn.image = Bundle.main.image(forResource: "delete_icn")
            
        } else {
            
            touchBarDeleteBtn.isEnabled = false
            touchBarDeleteBtn.state = .off
            touchBarDeleteBtn.image = Bundle.main.image(forResource: "delete_alt_icn")
            
        }
        
    }
    
    @objc func confirmTitleBtnStateChanged(_ sender: Notification) {
        
        guard let userInfo = sender.userInfo else { return }
        
        if userInfo["enabled"] as! Bool {
            
            touchBarConfirmTitleBtn.isEnabled = true
            touchBarConfirmTitleBtn.state = .on
            touchBarConfirmTitleBtn.image = NSImage(named: "text_check")?.imageTint(withColor: NSColor.systemYellow)
            
        } else {
            
            touchBarConfirmTitleBtn.isEnabled = false
            touchBarConfirmTitleBtn.state = .off
            touchBarConfirmTitleBtn.image = NSImage(named: "text_check")?.imageTint(withColor: NSColor.systemGray)
            
        }
        
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
