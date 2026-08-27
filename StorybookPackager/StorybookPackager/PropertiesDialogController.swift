//
//  PropertiesDialogController.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 12/10/18.
//  Copyright © 2018 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa
import SbXmlParser
import WebKit

class PropertiesDialogController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, WKNavigationDelegate {
    
    // general tab variables
    @IBOutlet weak var titleTxtfld: NSTextField!
    @IBOutlet weak var subtitleTxtfld: NSTextField!
    @IBOutlet weak var programCmbx: NSComboBox!
    @IBOutlet weak var courseNumTxtfld: NSTextField!
    @IBOutlet weak var releaseYearPopUp: NSPopUpButton!
    @IBOutlet weak var lengthTxtfld: NSTextField!
    @IBOutlet weak var calcLengthBtn: NSButton!
    @IBOutlet var generalInfo: NSTextView!
    
    // author tab variables
    @IBOutlet weak var authorNameCmbx: NSComboBox!
    @IBOutlet weak var authorPicImg: NSImageView!
    @IBOutlet weak var overridePicBtn: NSButton!
    @IBOutlet var authorProfileTxtvw: NSTextView!
    @IBOutlet weak var overrideProfileBtn: NSButton!
    
    // splash screen tab variables
    @IBOutlet weak var svgView: WKWebView!
    @IBOutlet weak var splashImgView: NSImageView!
    @IBOutlet weak var overrideSplashImgBtn: NSButton!
    @IBOutlet weak var removeLocalSplashImgBtn: NSButton!
    
    // settings tab variables
    @IBOutlet weak var splashImgType: NSPopUpButton!
    @IBOutlet weak var pageImgType: NSPopUpButton!
    @IBOutlet weak var analyticsOn: NSButton!
    @IBOutlet weak var mathJaxOn: NSButton!
    @IBOutlet weak var accentColorWell: NSColorWell!
    @IBOutlet weak var accentColorTxtfld: NSTextField!
    @IBOutlet weak var accentColorErrorLbl: NSTextField!
    
    // tab view error message label
    @IBOutlet weak var errorLbl: NSTextField!
    
    // private variables
    private var doc: Document?
    private var xmlObj: StorybookXml?

    private var properties: Setup?
    private var manifest: Manifest?
    private var authors: Array<Author>?
    private var programs: Array<Program>?
    private var authorProile: String?
    private var authorPic: NSImage?
    private let prefSettings = UserDefaults.standard
    private var loadedSplashUrl: URL?
    private var splashImgOverrode: Bool = false

    // remote splash-image loading state. The splash preview is fetched from the centralized
    // asset server (media.uwex.edu); a slow or unreachable server used to freeze the UI because
    // the download ran synchronously on the main thread (see issues #9 and #45). It is now an
    // async URLSession fetch with a timeout, a spinner, and a Cancel button that appears once
    // the load has been running long enough to look stuck.
    private var splashLoadTask: URLSessionDataTask?
    private var splashLoadToken: Int = 0
    private var splashCancelTimer: Timer?
    private let splashLoadTimeout: TimeInterval = 30.0

    private lazy var splashSpinner: NSProgressIndicator = {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    private lazy var splashCancelBtn: NSButton = {
        let button = NSButton(title: "Cancel", target: self, action: #selector(cancelSplashLoad))
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    var result: Result = Result()
    var completionHandler: ((Result) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        self.preferredContentSize = self.view.frame.size
        
        errorLbl.isHidden = true
        generalInfo.textContainerInset = NSSize(width: 5, height: 8)
        generalInfo.isAutomaticQuoteSubstitutionEnabled = false
        authorProfileTxtvw.textContainerInset = NSSize(width: 5, height: 8)
        authorProfileTxtvw.isAutomaticQuoteSubstitutionEnabled = false
        
        // release year menu: a leading placeholder so a document with no year doesn't get one
        // assigned just by opening this dialog
        releaseYearPopUp.removeAllItems()
        releaseYearPopUp.addItem(withTitle: ReleaseYear.placeholderTitle)
        releaseYearPopUp.addItems(withTitles: ReleaseYear.titles)
        releaseYearPopUp.target = self
        releaseYearPopUp.action = #selector(releaseYearChange(_:))

        // program name combo field
        programCmbx.usesDataSource = true
        programCmbx.dataSource = self
        programCmbx.delegate = self
        
        // author name combo field
        authorNameCmbx.usesDataSource = true
        authorNameCmbx.dataSource = self
        authorNameCmbx.delegate = self
        
        // webkitview
        svgView.navigationDelegate = self
        //svgView.setValue(false, forKey: "drawsBackground")
        
        // accent color variables for the settings screen
        accentColorErrorLbl.isHidden = true
        accentColorSetup()
        
    }
    
    override func viewWillAppear() {
        
        doc = (NSDocumentController.shared.currentDocument as! Document)
        xmlObj = doc!.getXmlObj()
        properties = xmlObj?.setup
        
        // general
        
        titleTxtfld.stringValue = properties!.title
        subtitleTxtfld.stringValue = properties!.subtitle
        programCmbx.stringValue = properties!.program
        // `course` stores the year as an "_r<year>" suffix; split it back apart. "000" is the
        // placeholder for a missing course number and is not shown to the user.
        let course = ReleaseYear.parse(course: properties!.course)

        courseNumTxtfld.stringValue = course.number == "000" ? "" : course.number

        if let year = course.year {

            // A document authored outside the offered range keeps its year rather than being
            // silently rewritten when this dialog is saved.
            if releaseYearPopUp.item(withTitle: String(year)) == nil {
                releaseYearPopUp.addItem(withTitle: String(year))
            }

            releaseYearPopUp.selectItem(withTitle: String(year))

        } else {
            releaseYearPopUp.selectItem(withTitle: ReleaseYear.placeholderTitle)
        }

        lengthTxtfld.stringValue = properties!.length
        generalInfo.string = properties!.generalInfo
        
        //author
        
        authorNameCmbx.stringValue = properties!.authorName
        authorProfileTxtvw.isEditable = false
        
        if (!properties!.authorProfile.isEmpty) {
            authorProfileTxtvw.string = properties!.authorProfile
            authorProfileTxtvw.isEditable = true
            overrideProfileBtn.state = .on
            properties!.overrideProfile = true
        }
        
        // splash screen
        
        splashImgOverrode = doc!.fileExistsInAssetsDir(fileName: "splash.\(doc!.getXmlObj().splashImgFormat)", subDirName: "", asBool: true) as! Bool
        
        // settings
        
        splashImgType.selectItem(withTitle: xmlObj!.splashImgFormat.uppercased())
        pageImgType.selectItem(withTitle: Util.shared.canonicalImageExt(xmlObj!.pageImgFormat).uppercased())

        // Shown, not set. Changing the slide image format converts or discards every image in the
        // presentation, which is not something a properties sheet should do on the way past — it
        // lives on File ▸ Convert Slide Images…, where it can say what it is about to do and be
        // cancelled. Left enabled here it silently orphaned every slide image, and the next save
        // deleted the lot.
        pageImgType.isEnabled = false
        pageImgType.toolTip = "Use File ▸ Convert Slide Images… to change the slide image format."
        accentColorTxtfld.stringValue = xmlObj!.accent
        accentColorWell.color = Util.shared.fromHex(hex: (xmlObj!.accent))
        
        if (xmlObj!.analytics) {
            analyticsOn.state = .on
        }

        if (xmlObj!.mathJax) {
            mathJaxOn.state = .on
        }
        
    }
    
    override func viewDidAppear() {
        
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
                    self.getSplashImg(path: URL(string: self.manifest!.sbplus_splash_directory)!)
                    
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
    
    // get JSON data for available programs
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
    
    // get splash screen image
    func getSplashImg(path: URL) {
        
        let splashImgFormat = doc!.getXmlObj().splashImgFormat
        
        if splashImgOverrode {
            
            let localSplash = doc!.fileExistsInAssetsDir(fileName: "splash.\(splashImgFormat)") as! FileWrapper
            
            if splashImgFormat == FileExtensions.SVG {

                let svgString = String(data: localSplash.regularFileContents!, encoding: .utf8)

                svgView.isHidden = false
                svgView.loadHTMLString(Util.shared.formatSvg(str: svgString!), baseURL: URL(string: "http://localhost"))

            } else {
                
                svgView.isHidden = true
                splashImgView.image = NSImage(data: localSplash.regularFileContents!)
                
            }
            
            removeLocalSplashImgBtn.isEnabled = true
            
            return
            
        }
        
        var course = ReleaseYear.compose(number: courseNumTxtfld.stringValue, year: selectedReleaseYear)

        if course.isEmpty {
            course = "default.jpg"
        } else {
            course = course + "." + splashImgFormat
        }
        
        let splashFile = programCmbx.stringValue + "/" + course
        let url = path.appendingPathComponent(splashFile)
        
        if loadedSplashUrl != url {

            let asSvg = splashImgFormat == FileExtensions.SVG && course != "default.jpg"

            guard let fallbackUrl = URL(string: manifest!.sbplus_root_directory + "images/default_splash.svg") else { return }

            loadRemoteSplash(primary: url, asSvg: asSvg, fallback: fallbackUrl)

            loadedSplashUrl = url

        }

    }

    // MARK: - Remote splash loading

    // Fetches the primary splash asset asynchronously and, if it can't be reached, falls back to
    // the centralized default splash. A spinner is shown while a request is in flight and a Cancel
    // button appears after `splashLoadTimeout` so a hung server can't leave the dialog stuck.
    private func loadRemoteSplash(primary: URL, asSvg: Bool, fallback: URL) {

        splashLoadToken += 1
        let token = splashLoadToken

        // A newer selection supersedes any request still in flight; stop the old download rather
        // than letting it run to completion just to be discarded by its stale token.
        splashLoadTask?.cancel()

        showSplashLoading()

        fetchSplashData(url: primary) { [weak self] data in

            guard let self = self, token == self.splashLoadToken else { return }

            if let data = data {

                self.hideSplashLoading()
                self.renderSplash(data: data, asSvg: asSvg)

            } else {

                // primary unreachable — show the centralized default splash instead
                self.fetchSplashData(url: fallback) { [weak self] fallbackData in

                    guard let self = self, token == self.splashLoadToken else { return }

                    self.hideSplashLoading()

                    if let fallbackData = fallbackData {
                        self.renderSplash(data: fallbackData, asSvg: true)
                    }

                }

            }

        }

    }

    // Async download with a timeout. The completion is always delivered on the main queue with the
    // data on success, or nil on any failure (timeout, non-200, cancellation, transport error).
    private func fetchSplashData(url: URL, completion: @escaping (Data?) -> Void) {

        var request = URLRequest(url: url)
        request.timeoutInterval = splashLoadTimeout

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in

            var result: Data? = nil

            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200, let data = data {
                result = data
            } else if let error = error {
                NSLog(error.localizedDescription)
            }

            DispatchQueue.main.async {
                completion(result)
            }

        }

        splashLoadTask = task
        task.resume()

    }

    private func renderSplash(data: Data, asSvg: Bool) {

        if asSvg {

            guard let svgString = String(data: data, encoding: .utf8) else { return }

            svgView.isHidden = false
            svgView.loadHTMLString(Util.shared.formatSvg(str: svgString), baseURL: URL(string: "http://localhost"))

        } else {

            svgView.isHidden = true
            splashImgView.image = NSImage(data: data)

        }

    }

    private func showSplashLoading() {

        guard let container = svgView.superview else { return }

        if splashSpinner.superview == nil {

            container.addSubview(splashSpinner)
            container.addSubview(splashCancelBtn)

            NSLayoutConstraint.activate([
                splashSpinner.centerXAnchor.constraint(equalTo: svgView.centerXAnchor),
                splashSpinner.centerYAnchor.constraint(equalTo: svgView.centerYAnchor),
                splashCancelBtn.centerXAnchor.constraint(equalTo: svgView.centerXAnchor),
                splashCancelBtn.topAnchor.constraint(equalTo: splashSpinner.bottomAnchor, constant: 12)
            ])

        }

        splashCancelBtn.isHidden = true
        splashSpinner.isHidden = false
        splashSpinner.startAnimation(nil)

        splashCancelTimer?.invalidate()
        splashCancelTimer = Timer.scheduledTimer(withTimeInterval: splashLoadTimeout, repeats: false) { [weak self] _ in
            self?.splashCancelBtn.isHidden = false
        }

    }

    private func hideSplashLoading() {

        splashCancelTimer?.invalidate()
        splashCancelTimer = nil
        splashSpinner.stopAnimation(nil)
        splashSpinner.isHidden = true
        splashCancelBtn.isHidden = true

    }

    @objc private func cancelSplashLoad() {

        // bump the token so any in-flight completion is ignored, then tear down the request
        splashLoadToken += 1
        splashLoadTask?.cancel()
        splashLoadTask = nil
        hideSplashLoading()

        // Forget the URL we were loading so picking the same course again retries instead of
        // being swallowed by the loadedSplashUrl de-dupe check.
        loadedSplashUrl = nil

    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        webView.takeSnapshot(with: .none, completionHandler: {(img, error) in
            
            if img != nil {
                webView.isHidden = true
                self.splashImgView.image = img!
            }
            
        })
        
    }
    
    // check for empty title
    @IBAction func titleOnEndEditing(_ sender: NSTextField) {
        checkForTitleError(title: sender.sanitize())
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
    
    // override splash image action
    @IBAction func overrideSplashImage(_ sender: NSButton) {
        
        let splashImgFormat = doc!.getXmlObj().splashImgFormat
        let imgBrowsePanel = NSOpenPanel()
        imgBrowsePanel.allowsMultipleSelection = false
        imgBrowsePanel.canChooseDirectories = false
        imgBrowsePanel.allowedFileTypes = [splashImgFormat]
        
        imgBrowsePanel.beginSheetModal(for: NSApp.keyWindow!, completionHandler: { result in
            
            if result == NSApplication.ModalResponse.OK {
                
                let fileName = "splash." + splashImgFormat
                
                if self.splashImgOverrode {
                    self.doc!.removeFileFromAssetsDir(file: fileName)
                }
                
                self.doc!.addFileToAssetsDir(name: fileName, path: imgBrowsePanel.url!)
                self.removeLocalSplashImgBtn.isEnabled = true
                self.doc!.updateChangeCount(.changeDone)
                
                if splashImgFormat == FileExtensions.SVG {
                    
                    do {
                        
                        let svgString = try String(contentsOf: imgBrowsePanel.url!, encoding: .utf8)
                        
                        self.svgView.loadHTMLString(Util.shared.formatSvg(str: svgString), baseURL: URL(string: "http://localhost"))
                        
                    } catch let error as NSError {
                        NSLog(error.localizedDescription)
                    }
                    
                } else {
                    
                    self.svgView.isHidden = true
                    self.splashImgView.image = NSImage(byReferencing: imgBrowsePanel.url!)
                    
                }
                
            }
            
        } )
        
    }
    
    @IBAction func removeLocalSplashImg(_ sender: NSButton) {
        
        sender.isEnabled = false
        splashImgOverrode = false
        doc!.removeFileFromAssetsDir(file: "splash.\(doc!.getXmlObj().splashImgFormat)")
        doc!.updateChangeCount(.changeDone)
        
        getSplashImg(path: URL(string: manifest!.sbplus_splash_directory)!)
        
    }
    
    // ok button action
    @IBAction func savePropertiesDialog(_ sender: NSButton) {
        
        self.view.window?.makeFirstResponder(nil)

        var newProperties: Setup = properties!
        var hasChange: Bool = false

        // Sanitize once per field and use the same value for both the comparison and the assignment.
        // Comparing the raw value against a trimmed one marked the document dirty on every save.
        let title = titleTxtfld.sanitize()
        let subtitle = subtitleTxtfld.sanitize()
        let program = programCmbx.sanitize()
        let courseNum = courseNumTxtfld.sanitize()
        let releaseYear = selectedReleaseYear
        let length = lengthTxtfld.sanitize()
        let info = generalInfo.sanitize()
        let authorName = authorNameCmbx.sanitize()
        let authorProfile = authorProfileTxtvw.sanitize()

        if (properties!.title != title) {
            newProperties.title = title
            hasChange = true
        }

        if (properties!.subtitle != subtitle) {
            newProperties.subtitle = subtitle
            hasChange = true
        }

        if program != properties!.program {
            newProperties.program = program
            hasChange = true
        }

        // Compose the stored `course` once, from the resolved number and the selected year, and
        // compare that against what was loaded. Assembling it in two steps used to leave a document
        // with no course number holding a bare "_r26", because the "000" fallback only ran when the
        // number itself had changed.
        let course = Util.shared.cleanString(str: ReleaseYear.compose(number: courseNum, year: releaseYear))

        if (properties!.course != course) {
            newProperties.course = course
            hasChange = true
        }

        // Not serialized — SbXmlReader never reads it back, and the year is recovered from `course`
        // on load. Kept in sync so the in-memory Setup isn't self-contradictory.
        newProperties.releaseYear = releaseYear.map { ReleaseYear.suffix(for: $0) } ?? ""

        if (properties?.length != length) {

            newProperties.length = length
            hasChange = true

        }

        if (properties?.generalInfo != info) {

            newProperties.generalInfo = info
            hasChange = true

        }

        if authorName != properties!.authorName {
            newProperties.authorName = authorName
            hasChange = true
        }

        if (overrideProfileBtn.state == .on) {

            if (properties?.authorProfile != authorProfile) {
                authorProfileTxtvw.isEditable = true
                newProperties.overrideProfile = true
                newProperties.authorProfile = authorProfile
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
        
        if (xmlObj?.splashImgFormat != splashImgType.titleOfSelectedItem!.lowercased()) {
            xmlObj?.splashImgFormat = splashImgType.titleOfSelectedItem!.lowercased()
            hasChange = true
        }
        
        if (xmlObj?.analytics != (analyticsOn.state == .on ? true : false)) {
            xmlObj?.analytics = analyticsOn.state == .on ? true : false
            hasChange = true
        }
        
        if (xmlObj?.mathJax != (mathJaxOn.state == .on ? true : false)) {
            xmlObj?.mathJax = mathJaxOn.state == .on ? true : false
            hasChange = true
        }
        
        if (xmlObj?.accent != accentColorTxtfld.stringValue) {
            
            if (!result.hasError) {
                xmlObj?.accent = accentColorTxtfld.stringValue
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

    // open the auto-calculate Length dialog as a sheet; on Save, write the estimate into the
    // Length field so the existing savePropertiesDialog() change-detection persists it normally
    @IBAction func openCalculateLength(_ sender: NSButton) {

        guard let calcController = storyboard?.instantiateController(withIdentifier: WindowIdentifiers.CALCULATE_LENGTH_DIALOG) as? CalculateLengthDialogController else { return }

        calcController.completionHandler = { (calcResult) -> () in

            if calcResult.OK {
                self.lengthTxtfld.stringValue = calcResult.lengthString
                self.dismiss(calcController)
            }

            if calcResult.CANCEL {
                self.dismiss(calcController)
            }

        }

        presentAsSheet(calcController)

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
    
    @IBAction func programChange(_ sender: NSComboBox) {
        
        if (!sender.stringValue.isEmpty) {
            
            if sender.stringValue != properties!.program {
                getSplashImg(path: URL(string: manifest!.sbplus_splash_directory)!)
            }
            
        }
        
    }
    
    // The selected year, or nil while the placeholder item is showing.
    private var selectedReleaseYear: Int? {
        guard let title = releaseYearPopUp.titleOfSelectedItem else { return nil }
        return Int(title)
    }

    @objc private func releaseYearChange(_ sender: NSPopUpButton) {

        guard manifest != nil else { return }

        // The splash image is looked up by "<program>/<course>_r<year>.<ext>".
        getSplashImg(path: URL(string: manifest!.sbplus_splash_directory)!)

    }

    @IBAction func courseChange(_ sender: NSTextField) {
        
        if (!sender.stringValue.isEmpty) {
            
            if sender.stringValue != properties!.course {
                getSplashImg(path: URL(string: manifest!.sbplus_splash_directory)!)
            }
            
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
    
    // BEGIN FUNCTIONS FOR ACCENT COLOR
    
    private func accentColorSetup() {
        
        // set accent color text with color hex value from accent color well
        let accentColor = accentColorWell.color
        accentColorTxtfld.stringValue = Util.shared.getHexFrom(color: accentColor)
        
        // add observer for accent color well change
        accentColorWell.addObserver(self, forKeyPath: "color", options: .new, context: nil)
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if (keyPath! == "color") {
            accentColorTxtfld.stringValue = Util.shared.getHexFrom(color: accentColorWell.color)
            clearAccentColorError()
        }
        
    }
    
    @IBAction func updateColorWell(_ sender: NSTextField) {
        
        var hex = sender.stringValue
        
        if (hex.hasPrefix("#")) {
            
            var offset = 6
            
            if (hex.count == 4) {
                offset = 3
            }
            
            hex = String(hex.suffix(offset))
            
        }
        
        if (hex.count == 0) {
            sender.stringValue = Util.shared.getHexFrom(color: accentColorWell.color)
            return
        }
        
        if (Util.shared.isHex(value: hex)) {
            
            if (hex.count == 3) {
                accentColorWell.color = Util.shared.fromHex(hex: hex + hex)
            } else {
                accentColorWell.color = Util.shared.fromHex(hex: hex)
            }
            
            clearAccentColorError()
            
        } else {
            showAccentColorError()
        }
        
    }
    
    private func clearAccentColorError() {
        accentColorTxtfld.layer?.borderWidth = 1
        accentColorTxtfld.layer?.borderColor = NSColor.darkGray.cgColor
        accentColorErrorLbl.stringValue = ""
        accentColorErrorLbl.isHidden = true
        result.hasError = false
    }
    
    private func showAccentColorError() {
        accentColorTxtfld.layer?.borderWidth = 1
        accentColorTxtfld.layer?.borderColor = NSColor.systemRed.cgColor
        accentColorErrorLbl.stringValue = "Invalid hexadecimal!"
        accentColorErrorLbl.isHidden = false
        result.hasError = true
    }
    
    // END FUNCTIONS FOR ACCENT COLOR
    
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
    var sbplus_root_directory: String
    var sbplus_program_json: String
    var sbplus_author_json: String
    var sbplus_author_directory: String
    var sbplus_splash_directory: String
}

struct Result {
    var OK: Bool = false
    var hasError: Bool = false
    var CANCEL: Bool = false
}

extension String {
    var alphanumeric: String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined().lowercased()
    }
}
