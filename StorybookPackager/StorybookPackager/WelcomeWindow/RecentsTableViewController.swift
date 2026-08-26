//
//  RecentsTableViewController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 3/3/22.
//  Copyright © 2022 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa

private let cellIndentifier = NSUserInterfaceItemIdentifier("RecentsTableCellView")

class RecentsTableViewController: NSViewController {

    @IBOutlet weak var noRecentProjectsLbl: NSTextField!
    @IBOutlet weak var projectsTableView: NSTableView!
    
    private var tableViewDS: NSTableViewDiffableDataSource<Int, URL>!
    private let urls: [URL]
    
    init(urls: [URL]) {
        self.urls = urls
        super.init(nibName: String(describing: Self.self), bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        projectsTableView.target = self
        projectsTableView.doubleAction = #selector(doubleAction(_:))
        projectsTableView.register(NSNib(nibNamed: "RecentsTableCellView", bundle: nil), forIdentifier: cellIndentifier)
        
        tableViewDS = NSTableViewDiffableDataSource<Int, URL>(tableView: projectsTableView, cellProvider: {(tableView, column, section, url) -> NSView in
            guard let cell = tableView.makeView(withIdentifier: cellIndentifier, owner: nil) as? RecentsTableCellView else {
                return NSView()
            }
            cell.configure(with: url)
            return cell
        })
        
        var snapshot = NSDiffableDataSourceSnapshot<Int, URL>()
        snapshot.appendSections([0])
        snapshot.appendItems(urls)
        
        tableViewDS.apply(snapshot, animatingDifferences: false)
        
        let containsURLs = !urls.isEmpty
        
        noRecentProjectsLbl.isHidden = containsURLs
        
        if (containsURLs) {
            projectsTableView.selectRowIndexes([0], byExtendingSelection: false)
        }
        
    }
    
    @objc private func doubleAction(_ sender: NSTableView) {
        
        let selectedRow = sender.selectedRow
        
        NSDocumentController.shared.openDocument(withContentsOf: urls[selectedRow], display: true, completionHandler: {(doc, opened, error) in
            
            if (error != nil) {
                
                Util.shared.showAlert(message: "An error occured when opening file. \(error!.localizedDescription)", informative: "", style: .warning)
                
            }
            
        })
        
    }
    
}
