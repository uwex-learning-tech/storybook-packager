//
//  PropertiesDialogController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/10/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import SbXmlParser

class PropertiesDialogController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate {
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var subtitleTxtfld: NSTextField!
    @IBOutlet weak var programCmbx: NSComboBox!
    @IBOutlet weak var courseNumTxtfld: NSTextField!
    @IBOutlet weak var releaseYearTxtfld: NSTextField!
    @IBOutlet weak var lengthTxtfld: NSTextField!
    @IBOutlet var generalInfo: NSTextView!
    @IBOutlet weak var authorNameCmbx: NSComboBox!
    @IBOutlet weak var authorPicTxtfld: NSTextField!
    @IBOutlet weak var authorPicBrowseBtn: NSButton!
    @IBOutlet weak var authorPicImg: NSImageView!
    @IBOutlet var authorProfileTxtvw: NSTextView!
    @IBOutlet weak var overrideProfileBtn: NSButton!
    @IBOutlet weak var errorLbl: NSTextField!
    
    private var properties: Setup?
    private var authors: Array<Author>?
    private var programs: Array<Program>?
    private var authorProile: String?
    
    var result: Result = Result()
    var completionHandler: ((Result) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        errorLbl.isHidden = true
        generalInfo.textContainerInset = NSSize(width: 5, height: 8)
        authorProfileTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        
        // program name combo field
        programCmbx.usesDataSource = true
        programCmbx.dataSource = self
        programCmbx.delegate = nil
        
        // author name combo field
        authorNameCmbx.usesDataSource = true
        authorNameCmbx.dataSource = self
        authorNameCmbx.delegate = self
        
    }
    
    override func viewWillAppear() {
        
        properties = (NSDocumentController.shared.currentDocument as! Document).getXmlObj().setup
        
        titleTxtfld.stringValue = properties!.title
        subtitleTxtfld.stringValue = properties!.subtitle
        programCmbx.stringValue = properties!.program
        courseNumTxtfld.stringValue = properties!.course
        releaseYearTxtfld.stringValue = properties!.releaseYear
        lengthTxtfld.stringValue = properties!.length
        generalInfo.string = properties!.generalInfo
        authorNameCmbx.stringValue = properties!.authorName
        authorProfileTxtvw.isEditable = false
        
        // get JSON data for program combo box
        let programUrlString = "https://media.uwex.edu/content/_programs.php"
        guard let programUrl = URL(string: programUrlString) else { return }
        
        URLSession.shared.dataTask(with: programUrl) { (data, response, error) in
            
            if error != nil {
                print(error!.localizedDescription)
            }
            
            guard let data = data else { return }
            
            do {
                //Decode retrived data with JSONDecoder
                let programsData = try JSONDecoder().decode([Program].self, from: data)
                
                //Get back to the main queue
                DispatchQueue.main.async {
                    
                    self.programs = programsData
                    self.programCmbx.reloadData()
                    
                    if (!self.programCmbx.stringValue.isEmpty) {
                        guard let index = self.programs?.index(where: { $0.name == self.programCmbx.stringValue }) else { return }
                        self.programCmbx.selectItem(at: index)
                    }
                    
                }
                
            } catch let jsonError {
                print(jsonError)
            }
            
            }.resume()
        
        // get JSON data for author name combo box
        let authorUrlString = "https://media.uwex.edu/content/media/storybook_support/author/_authors.php"
        guard let authorUrl = URL(string: authorUrlString) else { return }
        
        URLSession.shared.dataTask(with: authorUrl) { (data, response, error) in
            
            if error != nil {
                print(error!.localizedDescription)
            }
            
            guard let data = data else { return }
            
            do {
                //Decode retrived data with JSONDecoder
                let authorsData = try JSONDecoder().decode([Author].self, from: data)
                
                //Get back to the main queue
                DispatchQueue.main.async {
                    
                    self.authors = authorsData
                    self.authorNameCmbx.reloadData()
                    
                    if (!self.authorNameCmbx.stringValue.isEmpty) {
                        guard let index = self.authors?.index(where: { $0.name == self.authorNameCmbx.stringValue }) else { return }
                        self.authorNameCmbx.selectItem(at: index)
                    }
                    
                }
                
            } catch let jsonError {
                print(jsonError)
            }
            
        }.resume()
        
        if (!properties!.authorProfile.isEmpty) {
            authorProfileTxtvw.string = properties!.authorProfile
            authorProfileTxtvw.isEditable = true
            overrideProfileBtn.state = .on
        }
        
    }
    
    @IBAction func titleOnEndEditing(_ sender: NSTextField) {
        
        checkForTitleError(title: sender.stringValue)
        
    }
    
    @IBAction func savePropertiesDialog(_ sender: NSButton) {
        
        self.view.window?.makeFirstResponder(nil)
        
        var newProperties: Setup = properties!
        var hasChange: Bool = false
        
        if (properties?.title != titleTxtfld.stringValue) {
            newProperties.title = titleTxtfld.stringValue
            hasChange = true
        }
        
        if (properties?.subtitle != subtitleTxtfld.stringValue) {
            newProperties.subtitle = subtitleTxtfld.stringValue
            hasChange = true
        }
        
        if (properties?.program != programCmbx.stringValue) {
            newProperties.program = programCmbx.stringValue
            hasChange = true
        }

        if (properties?.course != courseNumTxtfld.stringValue) {
            newProperties.course = courseNumTxtfld.stringValue
            hasChange = true
        }
        
        if (properties?.releaseYear != releaseYearTxtfld.stringValue) {
            newProperties.releaseYear = releaseYearTxtfld.stringValue
            hasChange = true
        }
        
        if (properties?.length != lengthTxtfld.stringValue) {
            newProperties.length = lengthTxtfld.stringValue
            hasChange = true
        }

        if (properties?.generalInfo != generalInfo.string) {
            newProperties.generalInfo = generalInfo.string
            hasChange = true
        }
        
        if (properties?.authorName != authorNameCmbx.stringValue) {
            newProperties.authorName = authorNameCmbx.stringValue
            hasChange = true
        }
        
        if (overrideProfileBtn.state == .on) {
            
            if (properties?.authorProfile != authorProfileTxtvw.string) {
                newProperties.authorProfile = authorProfileTxtvw.string
                hasChange = true
            }
            
            if (properties?.overrideProfile == false) {
                newProperties.overrideProfile = true
                hasChange = true
            }
            
        } else {
            
            newProperties.authorProfile = ""
            newProperties.overrideProfile = false
            hasChange = true
            
        }
        
        if (hasChange && !result.hasError) {
            (NSDocumentController.shared.currentDocument as! Document).getXmlObj().setSetup(setup: newProperties)
            (NSDocumentController.shared.currentDocument as! Document).updateChangeCount(NSDocument.ChangeType.changeDone)
        }
        
        result.OK = true
        result.CANCEL = false
        completionHandler?(result)
        
    }
    
    @IBAction func cancelPropertiesDialog(_ sender: NSButton) {
        
        result.OK = false
        result.CANCEL = true
        completionHandler?(result)
        
    }
    
    override func mouseDown(with event: NSEvent) {
        self.view.window?.makeFirstResponder(nil)
    }
    
    private func checkForTitleError(title: String) {
        
        if title.isEmpty {
            result.hasError = true
            errorLbl.isHidden = false
            errorLbl.stringValue = "Please enter a title for the presentation."
        } else {
            result.hasError = false
            errorLbl.isHidden = true
            errorLbl.stringValue = ""
        }
        
    }
    
    // combo box protocols
    
    // Returns the number of items that the data source manages for the combo box
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        
        if ( comboBox.identifier?.rawValue == "authorsCombo") {
            
            guard let count = authors?.count else { return 0 }
            return count
            
        } else {
            
            guard let count = programs?.count else { return 0 }
            return count
            
        }
        
    }
    
    // Returns the object that corresponds to the item at the specified index in the combo box
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        
        if ( comboBox.identifier?.rawValue == "authorsCombo") {
            
            guard let name = authors?[index].name else { return "" }
            return name
            
        } else {
            
            guard let name = programs?[index].name else { return "" }
            return name
            
        }
        
    }
    
    @IBAction func authorChange(_ sender: NSComboBox) {
        
        if (!sender.stringValue.isEmpty) {
            guard let index = self.authors?.index(where: { $0.name == sender.stringValue }) else { return }
            sender.selectItem(at: index)
        }
        
    }
    
    @IBAction func profileOverrideChanged(_ sender: NSButton) {
        
        if (sender.state == .off) {
            authorProfileTxtvw.string = authorProile!
            authorProfileTxtvw.isEditable = false
        } else {
            authorProfileTxtvw.string = properties!.authorProfile
            authorProfileTxtvw.isEditable = true
        }
        
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        
        guard let combobox = notification.object as? NSComboBox else { return }
        
        let index = combobox.indexOfSelectedItem
        
        if (index >= 0 && index <= combobox.numberOfItems - 1) {
            
            let imgUrlStr = "https://media.uwex.edu/content/media/storybook_support/author/\(authors![index].file).jpg"
            let profileUrlStr = "https://media.uwex.edu/content/media/storybook_support/author/\(authors![index].file).json"
            
            guard let imgUrl = URL(string: imgUrlStr) else { return }
            
            URLSession.shared.dataTask(with: imgUrl) { (data, response, error) in
                
                if error != nil {
                    print(error!.localizedDescription)
                }
                
                guard let data = data else { return }
                
                DispatchQueue.main.async {
                    
                    self.authorPicImg.image = NSImage(data: data)
                    
                }
                
            }.resume()
            
            guard let profileUrl = URL(string: profileUrlStr) else { return }
            
            URLSession.shared.dataTask(with: profileUrl) { (data, response, error) in
                
                if error != nil {
                    print(error!.localizedDescription)
                }
                
                guard let data = data else { return }
                guard let profileObj = String(data: data, encoding: String.Encoding.utf8) else { return }
                
                var profile = profileObj.replacingOccurrences(of: "author(", with: "")
                profile = profile.replacingOccurrences(of: ");", with: "")
                
                do {
                    
                    //Decode retrived data with JSONDecoder
                    let profileData = try JSONDecoder().decode(Profile.self, from: profile.data(using: String.Encoding.utf8)!)
                    
                    //Get back to the main queue
                    DispatchQueue.main.async {
                        
                        self.authorProile = profileData.profile
                        
                        if (self.overrideProfileBtn.state == .off) {
                            self.authorProfileTxtvw.string = self.authorProile!
                        }
                        
                    }
                    
                } catch let jsonError {
                    print(jsonError)
                }
                
            }.resume()
            
        }

    }
    
}

struct Author: Codable {
    var file: String
    var name: String
}

struct Profile: Codable {
    var name: String
    var profile:String
}

struct Program: Codable {
    var name: String
}
