//
//  PropertiesDialogController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/10/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Cocoa
import sbplus_xml_parser

class PropertiesDialogController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate {
    
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var subtitleTxtfld: NSTextField!
    @IBOutlet weak var programCmbx: NSComboBox!
    @IBOutlet weak var courseNumTxtfld: NSTextField!
    @IBOutlet weak var releaseYearTxtfld: NSTextField!
    @IBOutlet weak var lengthTxtfld: NSTextField!
    @IBOutlet var generalInfo: NSTextView!
    @IBOutlet weak var authorNameCmbx: NSComboBox!
    @IBOutlet weak var authorPicImg: NSImageView!
    @IBOutlet weak var overridePicBtn: NSButton!
    @IBOutlet var authorProfileTxtvw: NSTextView!
    @IBOutlet weak var overrideProfileBtn: NSButton!
    @IBOutlet weak var errorLbl: NSTextField!
    
    private var doc: Document?
    private var properties: Setup?
    private var manifest: Manifest?
    private var authors: Array<Author>?
    private var programs: Array<Program>?
    private var authorProile: String?
    private var authorPic: NSImage?
    private let prefSettings = UserDefaults.standard
    
    var result: Result = Result()
    var completionHandler: ((Result) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        self.preferredContentSize = self.view.frame.size
        
        errorLbl.isHidden = true
        generalInfo.textContainerInset = NSSize(width: 5, height: 8)
        authorProfileTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        
        // program name combo field
        programCmbx.usesDataSource = true
        programCmbx.dataSource = self
        programCmbx.delegate = self
        
        // author name combo field
        authorNameCmbx.usesDataSource = true
        authorNameCmbx.dataSource = self
        authorNameCmbx.delegate = self
        
    }
    
    override func viewWillAppear() {
        
        doc = (NSDocumentController.shared.currentDocument as! Document)
        
        properties = doc!.getXmlObj().setup
        
        titleTxtfld.stringValue = properties!.title
        subtitleTxtfld.stringValue = properties!.subtitle
        programCmbx.stringValue = properties!.program
        
        courseNumTxtfld.stringValue = properties!.course
        
        let splitCourseNum = properties!.course.split(separator: "_")
        
        if splitCourseNum.count >= 1 {
            courseNumTxtfld.stringValue = String(splitCourseNum[0])
        }
        
        if splitCourseNum.count == 2 {
            releaseYearTxtfld.stringValue = String(splitCourseNum[1]).replacingOccurrences(of: "r", with: "")
        } else {
            releaseYearTxtfld.stringValue = ""
        }
        
        lengthTxtfld.stringValue = properties!.length
        generalInfo.string = properties!.generalInfo
        authorNameCmbx.stringValue = properties!.authorName
        authorProfileTxtvw.isEditable = false
        
        if (!properties!.authorProfile.isEmpty) {
            authorProfileTxtvw.string = properties!.authorProfile
            authorProfileTxtvw.isEditable = true
            overrideProfileBtn.state = .on
            properties!.overrideProfile = true
        }
        
        // get JSON data for program combo box
        guard let manifestUrl = prefSettings.url(forKey: Preferences.MANIFEST_URL) else { return }
        
        URLSession.shared.dataTask(with: manifestUrl) { (data, response, error) in
            
            if error != nil {
                NSLog(error!.localizedDescription)
            }
            
            guard let data = data else { return }
            
            do {
                //Decode retrived data with JSONDecoder
                let manifestData = try JSONDecoder().decode(Manifest.self, from: data)
                
                //Get back to the main queue
                DispatchQueue.main.async {
                    
                    self.manifest = manifestData
                    self.getPrograms(path: URL(string: self.manifest!.sbplus_program_json)!)
                    self.getAuthors(path: URL(string: self.manifest!.sbplus_author_json)!)
                    
                }
                
            } catch let jsonError {
                NSLog(jsonError.localizedDescription)
            }
            
        }.resume()
        
    }
    
    // get JSON data for author name combo box
    private func getAuthors(path: URL) {
        
        URLSession.shared.dataTask(with: path) { (data, response, error) in
            
            if error != nil {
                NSLog(error!.localizedDescription)
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
                        guard let index = self.authors?.firstIndex(where: { $0.name == self.authorNameCmbx.stringValue }) else { return }
                        self.authorNameCmbx.selectItem(at: index)
                    }
                    
                }
                
            } catch let jsonError {
                NSLog(jsonError.localizedDescription)
            }
            
        }.resume()
        
    }
    
    private func getPrograms(path: URL) {
        
        URLSession.shared.dataTask(with: path) { (data, response, error) in

            if error != nil {
                NSLog(error!.localizedDescription)
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
                        guard let index = self.programs?.firstIndex(where: { $0.name == self.programCmbx.stringValue }) else { return }
                        self.programCmbx.selectItem(at: index)
                    }

                }

            } catch let jsonError {
                NSLog(jsonError.localizedDescription)
            }

        }.resume()
        
    }
    
    // check for empty title
    @IBAction func titleOnEndEditing(_ sender: NSTextField) {
        checkForTitleError(title: sender.stringValue)
    }
    
    // override or remove author picture (locally)
    @IBAction func changeAuthorPic(_ sender: NSButton) {
        
        if doc!.fileExistsInAssetsDir(fileName: "\(authorNameCmbx.stringValue.alphanumeric).\(FileExtensions.JPG)") is FileWrapper {
            
            doc!.removeFileFromAssetsDir(file: "\(authorNameCmbx.stringValue.alphanumeric).\(FileExtensions.JPG)")
            authorPicImg.image = authorPic
            overridePicBtn.title = "Override Picture"
            
        } else {
            
            let imgBrowsePanel = NSOpenPanel()
            imgBrowsePanel.allowsMultipleSelection = false
            imgBrowsePanel.canChooseDirectories = false
            imgBrowsePanel.allowedFileTypes = [FileExtensions.JPG]
            
            imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
                
                if (result == NSApplication.ModalResponse.OK) {
                    
                    self.authorPicImg.image = NSImage(byReferencing: imgBrowsePanel.url!)
                    self.overridePicBtn.title = "Remove Local Picture"
                    self.doc!.addFileToAssetsDir(name: "\(self.authorNameCmbx.stringValue.alphanumeric).\(FileExtensions.JPG)", path: imgBrowsePanel.url!)
                    self.doc!.updateChangeCount(NSDocument.ChangeType.changeDone)
                    
                }
                
            } )
            
        }
        
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
        
        if let selectedValue = programCmbx.dataSource?.comboBox?(programCmbx, objectValueForItemAt: programCmbx.indexOfSelectedItem) as? String {
            
            if selectedValue != properties?.program {
                newProperties.program = selectedValue
                hasChange = true
            }
            
        } else {
            
            if (properties?.program != programCmbx.stringValue) {
                newProperties.program = programCmbx.stringValue
                hasChange = true
            }
            
        }

        if (properties?.course != courseNumTxtfld.stringValue) {
            
            newProperties.course = courseNumTxtfld.stringValue + "_r" + releaseYearTxtfld.stringValue.replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "r", with: "")
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
        
        if let selectedValue = authorNameCmbx.dataSource?.comboBox?(authorNameCmbx, objectValueForItemAt: authorNameCmbx.indexOfSelectedItem) as? String {
            
            if selectedValue != properties?.authorName {
                newProperties.authorName = selectedValue
                hasChange = true
            }
            
        } else {
            
            if (properties?.authorName != authorNameCmbx.stringValue) {
                newProperties.authorName = authorNameCmbx.stringValue
                hasChange = true
            }
            
        }
        
        if (overrideProfileBtn.state == .on) {
            
            if (properties?.authorProfile != authorProfileTxtvw.string) {
                authorProfileTxtvw.isEditable = true
                newProperties.overrideProfile = true
                newProperties.authorProfile = authorProfileTxtvw.string
                hasChange = true
            }
            
        } else {
            
            if (properties?.overrideProfile == true) {
                authorProfileTxtvw.isEditable = false
                newProperties.authorProfile = ""
                newProperties.overrideProfile = false
                hasChange = true
            }
            
        }
        
        if (hasChange && !result.hasError) {
            doc!.getXmlObj().setSetup(setup: newProperties)
            doc!.updateChangeCount(.changeDone)
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
        
        if ( comboBox.identifier?.rawValue == ObjIdentifiers.AUTHORS_COMBO_BOX) {
            
            guard let count = authors?.count else { return 0 }
            return count
            
        } else {
            
            guard let count = programs?.count else { return 0 }
            return count
            
        }
        
    }
    
    // Returns the object that corresponds to the item at the specified index in the combo box
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        
        guard index >= 0 else { return "" }
        
        if ( comboBox.identifier?.rawValue == ObjIdentifiers.AUTHORS_COMBO_BOX) {
            
            guard let name = authors?[index].name else { return "" }
            return name
            
        } else {
            
            guard let name = programs?[index].name else { return "" }
            return name
            
        }
        
    }
    
    @IBAction func authorChange(_ sender: NSComboBox) {
        
        if (!sender.stringValue.isEmpty) {
            guard let index = self.authors?.firstIndex(where: { $0.name == sender.stringValue }) else { return }
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
        guard manifest != nil else { return }
        
        if ( combobox.identifier?.rawValue == ObjIdentifiers.AUTHORS_COMBO_BOX) {
            
            let index = combobox.indexOfSelectedItem
            
            if (index >= 0 && index <= combobox.numberOfItems - 1) {
                
                guard let imageUrl = URL(string: manifest!.sbplus_author_directory)?.appendingPathComponent(authors![index].file).appendingPathExtension(FileExtensions.JPG) else { return }
                
                URLSession.shared.dataTask(with: imageUrl) { (data, response, error) in
                    
                    if error != nil {
                        NSLog(error!.localizedDescription)
                    }
                    
                    guard let data = data else { return }
                    
                    DispatchQueue.main.async {
                        
                        self.authorPic = NSImage(data: data)
                        self.authorPicImg.image = self.authorPic
                        
                        // check to see if there is a local author pic in file wrapper
                        guard let localPic = self.doc!.fileExistsInAssetsDir(fileName: "\(self.authorNameCmbx.stringValue.alphanumeric).\(FileExtensions.JPG)") as? FileWrapper else { return }
                        self.authorPicImg.image = NSImage(data: localPic.regularFileContents!)
                        self.overridePicBtn.title = "Remove Local Picture"
                        
                    }
                    
                    }.resume()
                
                guard let profileUrl = URL(string: manifest!.sbplus_author_directory)?.appendingPathComponent(authors![index].file).appendingPathExtension(FileExtensions.JSON) else { return }
                
                URLSession.shared.dataTask(with: profileUrl) { (data, response, error) in
                    
                    if error != nil {
                        NSLog(error!.localizedDescription)
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
                        NSLog(jsonError.localizedDescription)
                    }
                    
                    }.resume()
                
            }
            
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

struct Manifest: Codable {
    var sbplus_program_json: String
    var sbplus_author_json: String
    var sbplus_author_directory: String
}

extension String {
    var alphanumeric: String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined().lowercased()
    }
}
