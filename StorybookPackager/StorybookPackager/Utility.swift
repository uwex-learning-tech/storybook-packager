//
//  Utility.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 9/21/18.
//  Copyright © 2018 University of Wisconsin System. All rights reserved.
//

import Foundation
import Cocoa

final class Util {
    
    static let shared: Util = Util()
    
    private init() {}
    
    func createDirectory( path: String ) {
        
        do {
            
            var isDir: ObjCBool = false
            var directoryExists = false
            
            if ( FileManager.default.fileExists(atPath: path, isDirectory: &isDir) ) {
                
                if ( isDir.boolValue ) {
                    
                    directoryExists = true
                    
                }
                
            }
            
            if ( !directoryExists ) {
                
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                
            }
            
        } catch let error as NSError {
            
            print(error.localizedFailureReason as Any)
            
        }
        
    }
    
    func getUserHomeDirectory() -> URL {
        
        return FileManager.default.homeDirectoryForCurrentUser.absoluteURL
        
    }
    
    func getUserAppSupportDirectory() -> URL {
        
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        
    }
    
    func getUserDocumentDirectory() -> URL {
        
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
    }
    
    func getDefaultProjectDirectory() -> URL {
        
        let directory = URL(fileURLWithPath: self.getUserDocumentDirectory().path, isDirectory: true, relativeTo: self.getUserHomeDirectory()).appendingPathComponent(self.getAppName())
        
        return directory.absoluteURL
        
    }
    
    func getAppName() -> String {
        
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)!
        
    }
    
    func writeToFile(path: URL, content: String) {
    
        do {
            
            try content.write(to: path, atomically: true, encoding: .utf8)
            
        } catch let error as NSError {
            
            print(error.localizedFailureReason as Any)
            
        }
        
    }
    
    func read(path:URL) -> String {
        
        do {
            
            return try String(contentsOf: path)
            
        } catch let error as NSError {
            
            print(error.localizedFailureReason as Any)
            
        }
        
        return ""
        
    }
    
    func encodeRecentProjects(obj: Array<URL>) -> String {
        
        do {
            
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(obj)
            
            return String(data: jsonData, encoding: String.Encoding.utf8)!
            
        } catch let error as NSError {
            
            print(error.localizedFailureReason as Any)
            
        }
        
        return ""
        
    }
    
    func decodeRecentProjects(json: String) -> Array<URL> {
        
        do {
            
            let jsonDecoder = JSONDecoder()
            return try jsonDecoder.decode(Array<URL>.self, from: json.data(using: .utf8)!)
            
        } catch let error as NSError {
            
            print(error.localizedFailureReason as Any)
            
        }
        
        return Array<URL>()
        
    }
    
    func getHexFrom(color: NSColor) -> String {
        
        // Get the red, green, and blue components of the color
        var r :CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(
            format: "%02X%02X%02X",
            Int(r * 255.0),
            Int(g * 255.0),
            Int(b * 255.0)
        )
        
    }
    
    func fromHex(hex: String) -> NSColor {
        
        if (isHex(value: hex)) {
            
            var theInt: UInt32 = 0
            let scanner = Scanner(string: hex)
            scanner.scanHexInt32(&theInt)
            let red = CGFloat((theInt & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((theInt & 0x00FF00) >> 8) / 255.0
            let blue = CGFloat((theInt & 0x0000FF) >> 0) / 255.0
            return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
            
        } else {
            return Optional.none ?? NSColor.gray
        }
        
    }
    
    func isHex(value: String) -> Bool {
        return value.range(of: "([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})", options: .regularExpression) != nil
    }
    
    func showAlert(message: String, style: NSAlert.Style) {
        
        let alert = NSAlert()
        
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.alertStyle = style
        
        alert.runModal()
        
    }
    
    func formatPageNum(num: Int) -> String {
        
        if num >= 1 && num < 10 {
            
            return "0\(num)"
            
        }
        
        return "\(num)"
        
    }
    
    func formatSvg(str: String) -> String {
        
        var svg = str
        
        svg = svg.replacingOccurrences(of: "width=\"(\\d*)pt\"", with: "width=\"640\"", options: [.regularExpression, .caseInsensitive], range: nil)
        svg = svg.replacingOccurrences(of: "height=\"(\\d*)pt\"", with: "height=\"360\" preserveAspectRatio=\"xMinYMid meet\"", options: [.regularExpression, .caseInsensitive], range: nil)
        
       return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\" /><style>body{margin:0;width:640px;height:360px;overflow:hidden;}</style></head><body>\(svg)</body></html>"
        
    }
    
    func formatImgHtml(base64: String) -> String {
        
        return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\" /><style>body{margin:0;width:640px;height:360px;overflow:hidden;}.img{width:640px;height:360px;background-image: url(data:image/png;base64,\(url));background-repeat: no-repeat;background-size:cover;}</style></head><body><div class=\"img\"></div></body></html>"
        
    }
    
    func timeAsString(timeInterval: TimeInterval) -> String {
        
        var seconds = 0
        var minutes = 0
        
        seconds = Int(timeInterval) % 60
        minutes = (Int(timeInterval) / 60) % 60
        
        return String(format: "%0.2d:%0.2d", minutes, seconds)
        
    }
    
    func formatPageTypeString(string: String) -> String {
        
        var result = string.lowercased()
        
        result = String(result.replacingOccurrences(of: " and ", with: "-"))
        
        return result
        
    }
    
}
