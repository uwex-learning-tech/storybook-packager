//
//  ViewController.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class StartViewController: NSViewController {
    
    var recentProjects: Array<URL> = []
    
    @IBOutlet weak var recentProjectView: NSTableView!
    @IBOutlet weak var clearRecentBtn: NSButton!
    
    @IBAction func clearRecentProjects(_ sender: Any) {
        
        NSDocumentController.shared.clearRecentDocuments(nil)
        recentProjects.removeAll()
        recentProjectView.reloadData();
        
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
        
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
}

extension StartViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return recentProjects.count
    }

}

extension StartViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        if ( recentProjects.count <= 0 ) {
            return nil
        }
        
        if ( tableColumn == recentProjectView.tableColumns[0] ) {
            
            if let cell = recentProjectView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.project), owner: nil ) as? RecentProjectTableCellView {
                
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
        
        print( recentProjects[recentProjectView.selectedRow] )
        NSDocumentController.shared.openDocument(withContentsOf: recentProjects[recentProjectView.selectedRow], display: true, completionHandler: {(doc, opened, error) in
            
            if (error != nil) {
                
                Util.shared.showAlert(message: "An error occured when opening file. \(error!.localizedDescription)", style: .warning)
                
            }
            
        })
        
    }

}

