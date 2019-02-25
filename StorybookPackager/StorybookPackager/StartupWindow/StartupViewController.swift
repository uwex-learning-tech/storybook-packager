//
//  ViewController.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class StartupViewController: NSViewController {
    
    var recentProjects: Array<URL> = []
    
    @IBOutlet weak var recentProjectView: NSTableView!
    @IBOutlet weak var clearRecentBtn: NSButton!
    @IBOutlet weak var versionLbl: NSTextField!
    
    @IBAction func clearRecentProjects(_ sender: Any) {
        
        NSDocumentController.shared.clearRecentDocuments(nil)
        recentProjects.removeAll()
        recentProjectView.reloadData();
        
    }
    
    @IBAction func newPresentation(_ sender: NSButton) {
        NSDocumentController.shared.newDocument(sender)
        self.view.window?.close()
    }
    
    @IBAction func openPresenation(_ sender: NSButton) {
        
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
                    
                    Util.shared.showAlert(message: "An error occured when opening file. \(error!.localizedDescription)", style: .warning)
                    
                }
                
            })
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get recent documents from NSDocumentController
        recentProjects = NSDocumentController.shared.recentDocumentURLs
        
        // enable clear recent button if there are recent documents
        if ( recentProjects.count >= 1 ) {
            self.clearRecentBtn.isEnabled = true
        }
        
        // Set delegate and dataSource for Recent Projects table view
        recentProjectView.delegate = self
        recentProjectView.dataSource = self
        recentProjectView.target = self
        recentProjectView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        versionLbl.stringValue = "\((Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)!) (\((Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)!))"
        
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
}

extension StartupViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return recentProjects.count
    }

}

extension StartupViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        if ( recentProjects.count <= 0 ) {
            return nil
        }
        
        if ( tableColumn == recentProjectView.tableColumns[0] ) {
            
            if let cell = recentProjectView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ObjIdentifiers.PROJECT_CELL), owner: nil ) as? RecentProjectTableCellView {
                
                let path = recentProjects[row]
                let name = path.deletingPathExtension().lastPathComponent
                let relativePath = path.deletingLastPathComponent().relativePath
                
                cell.recentProjTitle.stringValue = name
                cell.recentProjLocation.stringValue = relativePath.ns.abbreviatingWithTildeInPath
                
                return cell
                
            }
            
        }

        return nil

    }
    
    @objc func tableViewDoubleClick(_ sender: AnyObject) {
        
        NSDocumentController.shared.openDocument(withContentsOf: recentProjects[recentProjectView.selectedRow], display: true, completionHandler: {(doc, opened, error) in
            
            if (error != nil) {
                
                Util.shared.showAlert(message: "An error occured when opening file. \(error!.localizedDescription)", style: .warning)
                
            }
            
        })
        
    }

}

extension String { var ns : NSString {return self as NSString} }
