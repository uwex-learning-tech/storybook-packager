//
//  ViewController.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class StartViewController: NSViewController {
    
    @IBOutlet weak var recentProjectView: NSTableView!
    @IBOutlet weak var clearRecentBtn: NSButton!
    
    @IBAction func newPresentationBtn(_ sender: Any) {
        
        openNewPresenationView()
        
    }
    
    var recentProjects: Array<URL> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // enable clear recent button if there is recent projects
        // else stay disabled and change text color to gray
        if ( recentProjects.count >= 1 ) {
            
            self.clearRecentBtn.isEnabled = true
            
        } else {
            
            let pstyle = NSMutableParagraphStyle()
            pstyle.alignment = .left
            
            self.clearRecentBtn.attributedTitle = NSAttributedString(string: self.clearRecentBtn.title, attributes: [NSAttributedString.Key.foregroundColor: NSColor.gray, NSAttributedString.Key.paragraphStyle: pstyle])
            
        }
        
        // get recent projects from JSON file in app support directory
        
        let recentProjectFile: URL = Util.shared.getRecentProjectsJsonFile()
        
        if (FileManager.default.fileExists(atPath: recentProjectFile.path) ) {
            
            let fileContent:String = Util.shared.read(path: recentProjectFile)

            self.recentProjects = Array(Util.shared.decodeRecentProjects(json: fileContent))
            
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
    
    func openNewPresenationView() {
        
        let newPresentationWindowController = NSStoryboard(name: StoryboardIdentifiers.main, bundle: nil).instantiateController(withIdentifier: SegueIdentifiers.presentation) as! NSWindowController
        
        newPresentationWindowController.showWindow(self)
        newPresentationWindowController.window?.makeMain()
        
        self.view.window?.windowController?.close()
        
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
                
                cell.recentProjTitle.stringValue = recentProjects[row].lastPathComponent
                cell.recentProjLocation.stringValue = recentProjects[row].path.ns.abbreviatingWithTildeInPath
                
                return cell
                
            }
            
        }

        return nil

    }
    
    @objc func tableViewDoubleClick(_ sender: AnyObject) {
        
        print( recentProjects[recentProjectView.selectedRow].lastPathComponent )
        
    }

}

