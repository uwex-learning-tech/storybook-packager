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
    @IBAction func newPresentationBtn(_ sender: Any) {
        
        openNewPresenationView()
        
    }
    
    var recentProjects: Array<String> = ["ap340_lesson5", "smgt115_lesson2", "apc340_lesson5"]
    var recentLocations: Array<String> = ["~/Desktop", "~/Document", "~/Desktop/Test"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            
            let userAppSupportDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appSupportDirectory = userAppSupportDirectory.appendingPathComponent((Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)!, isDirectory: true)
            var isDir: ObjCBool = false
            var directoryExists = false
            
            if ( FileManager.default.fileExists(atPath: appSupportDirectory.path, isDirectory: &isDir) ) {
                
                if ( isDir.boolValue ) {
                    
                   directoryExists = true
                    
                }
                
            }
            
            if ( !directoryExists ) {
                try FileManager.default.createDirectory(atPath: appSupportDirectory.path, withIntermediateDirectories: true, attributes: nil)
            }
            
        } catch let error as NSError {
            print(error.localizedFailureReason as Any)
        }
        
        // Do any additional setup after loading the view.
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
        
        let newPresentationWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "PresentationWindow") as! NSWindowController
        
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
            
            if let cell = recentProjectView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "projectCell"), owner: nil ) as? RecentProjectTableCellView {
                
                cell.recentProjTitle.stringValue = recentProjects[row]
                cell.recentProjLocation.stringValue = recentLocations[row]
                
                return cell
                
            }
            
        }

        return nil

    }
    
    @objc func tableViewDoubleClick(_ sender: AnyObject) {
        
        print( recentProjects[recentProjectView.selectedRow] )
        
    }

}

