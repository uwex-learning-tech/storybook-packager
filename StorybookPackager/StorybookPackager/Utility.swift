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
    
    func parseAssetName(string: String) -> String {
        
        if let regex = try? NSRegularExpression(pattern: "(\\d)", options: NSRegularExpression.Options.caseInsensitive) {
            let matched = regex.firstMatch(in: string, range: NSRange(location: 0, length: string.count))
            let to = string.index(string.startIndex, offsetBy: matched!.range.location, limitedBy: string.endIndex)
            return String(string.prefix(upTo: to!))
        }
        
        return ""
        
    }
    
    func formatSvg(str: String) -> String {
        
        var svg = str
        
        svg = svg.replacingOccurrences(of: "width=\"(\\d*)pt\"", with: "width=\"100%\"", options: [.regularExpression, .caseInsensitive], range: nil)
        svg = svg.replacingOccurrences(of: "height=\"(\\d*)pt\"", with: "height=\"100%\" preserveAspectRatio=\"xMinYMid meet\"", options: [.regularExpression, .caseInsensitive], range: nil)
        
        return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\" /><style>html{width:100%;height:100%;overflow:hidden;}body{margin:0;padding:0;width:100%;height:100%;}</style></head><body oncontextmenu=\"return false;\">\(svg)</body></html>"
        
    }
    
    func formatImgHtml(base64: String) -> String {
        
        return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\" /><style>html{width:100%;height:100%;overflow:hidden;}body{margin:0;padding:0;width:100%;height:100%;}img{display:block;width:100%;height:100%;}</style></head><body oncontextmenu=\"return false;\"><img src=\"data:image/png;base64,\(base64)\" /></body></html>"
        
    }
    
    func formatIframe(str: String, type: String) -> String {
        
        var url: String = ""
        
        switch type {
            
        case "vimeo":
            url = "https://player.vimeo.com/video/\(str)"
            break
        default:
            url = "https://www.youtube.com/embed/\(str)"
            break
            
        }
        
        return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\" /><style>body{margin:0;width:640px;height:360px;overflow:hidden;}</style></head><body oncontextmenu=\"return false;\"><div style=\"padding:56.25% 0 0 0;position:relative;\"><iframe style=\"position:absolute;top:0;left:0;width:100%;height:100%;\" src=\"\(url)\" frameborder=\"0\" webkitallowfullscreen allowfullscreen></iframe></div></body></html>"
        
    }
    
    func timeAsString(timeInterval: TimeInterval) -> String {
        
        var seconds = 0
        var minutes = 0
        
        seconds = Int(timeInterval) % 60
        minutes = (Int(timeInterval) / 60) % 60
        
        return String(format: "%0.2d:%0.2d", minutes, seconds)
        
    }
    
    func timeStringToSeconds(time: String) -> Double {
        
        let parts = time.split(separator: ":")
        guard parts.count >= 2 && parts.count <= 3 else { return 0.0 }
        
        var h: Double = 0.0
        var m: Double = 0.0
        var s: Double = 0.0
        
        if parts.count == 2 {
            m = Double(parts[0])!
            s = Double(parts[1])!
        } else if parts.count == 3 {
            h = Double(parts[0])!
            m = Double(parts[1])!
            s = Double(parts[2])!
        }
        
        return (h * 60) + (m * 60) + (s)
        
    }
    
    func formatPageTypeString(string: String) -> String {
        
        var result = string.lowercased()
        
        result = String(result.replacingOccurrences(of: " and ", with: "-"))
        result = String(result.replacingOccurrences(of: " ", with: ""))
        
        return result
        
    }
    
    func getPageTypeIndex(type: String, collection: Array<String>) -> Int {
        
        for (index, item) in collection.enumerated() {
            
            if type == formatPageTypeString(string: item) {
                return index
            }
            
        }
        
        return -1
        
    }
    
    func parseNumFromFileName(string: String) -> String {
        
        var num = string
        
        if let regex = try? NSRegularExpression(pattern: "([0-9]*-?[0-9])$", options: NSRegularExpression.Options.caseInsensitive) {
            let matched = regex.matches(in: string, range: NSRange(location: 0, length:  string.count))
            num = matched.map{ String(string[Range($0.range, in: string)!]) }.joined()
        }
        
        let numArray = num.split(separator: "-")
        
        if numArray[0].count == 1 {
            num = "0" + num
        }
        
        return num
        
    }
    
    func getQuizType(type: String) -> String {
        
        switch type {
        case QuizTypes.SHORT_ANSWER:
            return "Short Answer"
        case QuizTypes.FILL_IN_THE_BLANK:
            return "Fill In The Blank"
        case QuizTypes.MULTIPLE_CHOICE:
            return "Multiple Choice"
        case QuizTypes.MULTIPLE_ANSWER:
            return "Multiple Answer"
        default:
            return ""
        }
        
    }
    
}
