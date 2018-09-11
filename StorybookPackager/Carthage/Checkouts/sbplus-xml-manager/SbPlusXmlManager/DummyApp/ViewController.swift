//
//  ViewController.swift
//  DummyApp
//
//  Created by Ethan Lin on 7/5/18.
//  Copyright © 2018 University of Wisconsin System Office of Academic and Student Affairs. All rights reserved.
//

import UIKit
import SbPlusXmlManager

class ViewController: UIViewController {

    @IBOutlet weak var output: UITextView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        self.getXMLPath()
        
    }

    override func didReceiveMemoryWarning() {
        
        super.didReceiveMemoryWarning()
        
        // Dispose of any resources that can be recreated.
        
    }
    
    func getXMLPath() {
        
        let xmlMngr = SbXmlManager()
        
        do {
            
            output.text = try xmlMngr.read( path: "file:///Volumes/Macintosh%20HD/Users/ethan.lin/Desktop/sbplus.xml" )
            
        } catch let error as NSError {
            
            output.text = error.localizedFailureReason
            
        }
        
    }
    

}

