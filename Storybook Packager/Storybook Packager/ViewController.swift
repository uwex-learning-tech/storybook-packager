//
//  ViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 9/7/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var recentProjectView: NSTableView!
    
    var recentProjects: Array<String> = ["ap340_lesson5", "smgt115_lesson2", "apc340_lesson5"]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        recentProjectView.delegate = self
        recentProjectView.dataSource = self
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

extension ViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return recentProjects.count
    }
    
}

extension ViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        if ( recentProjects.count <= 0 ) {
            return nil
        }
        
        if ( tableColumn == recentProjectView.tableColumns[0] ) {
            
            print("hit")
            
            if let cell = recentProjectView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "projectCell"), owner: nil ) as? NSTableCellView {
                
                print("cellhit")
                
                cell.textField?.stringValue = recentProjects[row]
                
                return cell
                
            }
            
        }

        return nil
        
    }
    
}
