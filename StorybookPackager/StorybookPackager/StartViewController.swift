//
//  ViewController.swift
//  StorybookPackager
//
//  Created by Ethan Lin on 9/11/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class StartViewController: NSViewController {
    
    let recentProjectFile: URL = Util.shared.getRecentProjectsJsonFile()
    var recentProjects: Array<URL> = []
    
    @IBOutlet weak var recentProjectView: NSTableView!
    @IBOutlet weak var clearRecentBtn: NSButton!
    @IBAction func clearRecentProjects(_ sender: Any) {
        
        // create recent project json file if it does not exist
        if (FileManager.default.fileExists(atPath: recentProjectFile.path) ) {
            
            Util.shared.writeToFile(path: recentProjectFile, content: Util.shared.encodeRecentProjects(obj: Array<URL>()))
            
            recentProjects.removeAll()
            
            recentProjectView.reloadData();
            clearRecentBtn.isEnabled = false
            
        }
        
    }
    
    @IBAction func newPresentationBtn(_ sender: Any) {
        
        openNewPresenationView()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get recent projects from JSON file in app support directory
        
        if (FileManager.default.fileExists(atPath: recentProjectFile.path) ) {
            
            let fileContent:String = Util.shared.read(path: recentProjectFile)

            self.recentProjects = Array(Util.shared.decodeRecentProjects(json: fileContent))
            
        }
        
        // enable clear recent button if there is recent projects
        // else stay disabled and change text color to gray
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

