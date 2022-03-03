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
    
    @IBOutlet weak var windowToolbar: NSToolbar!
    @IBOutlet weak var noNetworkStatus: NSToolbarItem!
    @IBOutlet weak var touchBarDeleteBtn: NSButton!
    @IBOutlet weak var touchBarConfirmTitleBtn: NSButton!
    
    let reachability = try! Reachability()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        shouldCascadeWindows = true
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // load accessory view
        //createAccessoryViewController()
        
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
        case .unavailable:
            
            self.windowToolbar.insertItem(withItemIdentifier: NSToolbarItem.Identifier.init(rawValue: "noNetworkStatus"), at: self.windowToolbar.items.count)
            
        default:
            
            self.windowToolbar.removeItem(at: self.windowToolbar.items.count - 1)
            
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
        self.window?.subtitle = with
    }
    
//    fileprivate func createAccessoryViewController() {
//
//        let accessoryViewController = NSTitlebarAccessoryViewController()
//        accessoryViewController.view = accessoryView
//        accessoryViewController.layoutAttribute = .right
//        self.window?.addTitlebarAccessoryViewController(accessoryViewController)
//
//    }

}
