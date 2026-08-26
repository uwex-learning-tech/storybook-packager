//
//  MainWelcomeViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/3/22.
//  Copyright © 2022 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

class MainWelcomeViewController: NSViewController {

    @IBOutlet weak var closeBtn: HoverButton!
    @IBOutlet weak var appNameLbl: NSTextField!
    @IBOutlet weak var newProjectBtn: NSButton!
    @IBOutlet weak var openProjectBtn: NSButton!
    @IBOutlet weak var versionLbl: NSTextField!
    @IBOutlet weak var copyrightLbl: NSTextField!
    
    private struct Button {
        let title: String
        let subtitle: String
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        closeBtn.alphaValue = 0.25
        appNameLbl.stringValue = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
        versionLbl.stringValue = "Version \((Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)!) (\((Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)!))"
        copyrightLbl.stringValue = MainWelcomeViewController.splashCopyright(
            Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? " ")
        
        view.addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
        
        setupButtons()
    }
    
    /// The notice as the welcome window can show it.
    ///
    /// The window gives it a single 10pt line across the panel, and the organization's name in full
    /// overruns that — the line was being clipped mid-sentence, which reads worse than an
    /// abbreviation does. The About box lays the same notice out with room to spare and keeps the
    /// name in full, so this shortens it here rather than in Info.plist, where both read it from.
    static func splashCopyright(_ notice: String) -> String {

        return notice.replacingOccurrences(of: "Office of Online & Professional Learning Resources",
                                           with: "OPLR")

    }

    private func setupButtons() {
        
        let models = [
            Button(title: "Create a new Storybook project", subtitle: "Create a new Storybook+ presentation."),
            Button(title: "Open a Storybook project", subtitle: "Open an existing Storybook project.")
        ]
        
        let buttons: [NSButton] = [newProjectBtn, openProjectBtn]
        
        for (model, button) in zip(models, buttons) {
            let text = NSMutableAttributedString(string: "   \(model.title)\n   ", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor
             ])
            text.append(NSAttributedString(string: model.subtitle, attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor
             ]))
            button.attributedTitle = text
        }
        
    }
    
    override func mouseEntered(with event: NSEvent) {
        closeBtn.alphaValue = 1
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.allowsImplicitAnimation = true
            closeBtn.alphaValue = 0.25
        }
    }
    
    @IBAction func closeWelcomeWindow(_ sender: Any) {
        view.window?.close()
    }
    
    @IBAction func createNewProject(_ sender: Any) {
        NSDocumentController.shared.newDocument(sender)
        self.view.window?.close()
    }
    
    @IBAction func openProject(_ sender: Any) {
        
        let openPanel = NSOpenPanel()
        
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowedFileTypes = ["sbproj"]
        
        if (openPanel.runModal() == NSApplication.ModalResponse.OK) {
            
            guard let url = openPanel.url else {
                return
            }
            
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true, completionHandler: {(doc, opened, error) in
                
                if (error != nil) {
                    
                    Util.shared.showAlert(message: "An error occured when opening file. \(error!.localizedDescription)", informative: "", style: .warning)
                    
                }
                
            })
            
            self.view.window?.close()
            
        }
        
    }
    
    
}
