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
    
    func openNewPresenationView() {
        
        let newPresentationWindowController = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "PresentationWindow")) as! NSWindowController
        
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

            if let cell = recentProjectView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "projectCell"), owner: nil ) as? NSTableCellView {

                cell.textField?.stringValue = recentProjects[row]

                return cell

            }

        }

        return nil

    }

}

