//
//  Utility.swift
//  Storybook Packager
//
//  Created by Ethan Lin on 9/21/18.
//  Copyright © 2018 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Foundation
import Cocoa

final class Util {
    
    // made this class into a singleton
    static let shared: Util = Util()
    
    // private empty initializer/constructor
    private init() {}
    
    /****** Utilties Methods ******/
    
    func createDirectory(path: String) {
        
        do {
            
            var isDir: ObjCBool = false
            var directoryExists = false
            
            if (FileManager.default.fileExists(atPath: path, isDirectory: &isDir)) {
                
                if (isDir.boolValue) {
                    directoryExists = true
                }
                
            }
            
            if (!directoryExists) {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            }
            
        } catch let error as NSError {
            NSLog(error.localizedFailureReason!)
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
        return URL(fileURLWithPath: getUserDocumentDirectory().path, isDirectory: true, relativeTo: getUserHomeDirectory()).appendingPathComponent(getAppName()).absoluteURL
    }
    
    func getAppName() -> String {
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)!
    }
    
//    func writeToFile(path: URL, content: String) {
//
//        do {
//
//            try content.write(to: path, atomically: true, encoding: .utf8)
//
//        } catch let error as NSError {
//
//            print(error.localizedFailureReason as Any)
//
//        }
//
//    }
    
//    func read(path:URL) -> String {
//
//        do {
//
//            return try String(contentsOf: path)
//
//        } catch let error as NSError {
//
//            print(error.localizedFailureReason as Any)
//
//        }
//
//        return ""
//
//    }
    
//    func encodeRecentProjects(obj: Array<URL>) -> String {
//
//        do {
//
//            let jsonEncoder = JSONEncoder()
//            let jsonData = try jsonEncoder.encode(obj)
//
//            return String(data: jsonData, encoding: String.Encoding.utf8)!
//
//        } catch let error as NSError {
//
//            print(error.localizedFailureReason as Any)
//
//        }
//
//        return ""
//
//    }

//    func decodeRecentProjects(json: String) -> Array<URL> {
//
//        do {
//
//            let jsonDecoder = JSONDecoder()
//            return try jsonDecoder.decode(Array<URL>.self, from: json.data(using: .utf8)!)
//
//        } catch let error as NSError {
//
//            print(error.localizedFailureReason as Any)
//
//        }
//
//        return Array<URL>()
//
//    }
    
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
            
            var theInt: UInt64 = 0
            let scanner = Scanner(string: hex)
            scanner.scanHexInt64(&theInt)
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
    
    func showAlert(message: String, informative: String, style: NSAlert.Style) {
        
        let alert = NSAlert()
        
        alert.messageText = message
        alert.informativeText = informative
        alert.addButton(withTitle: "OK")
        alert.alertStyle = style
        
        alert.runModal()
        
    }
    
    func browseForFile(allowedTypes: [String]) -> URL? {

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = allowedTypes

        return panel.runModal() == NSApplication.ModalResponse.OK ? panel.url : nil

    }

    func animateIn(image: NSImageView) {
        
        NSAnimationContext.runAnimationGroup({
            context in
            context.duration = 0.25
            
            image.animator().alphaValue = 1
            
        }, completionHandler: nil)
        
    }
    
    func cleanString( str: String ) -> String {
        return TextSanitizer.sanitized(str)
    }

    // Title-cases a page title the way a copy editor would, rather than the way `capitalized` does.
    // See TitleCase.swift for the rules.
    func titleCase( str: String ) -> String {
        return TitleCase.titleCased(str)
    }

    func formatPageNum(num: Int) -> String {
        
        if num >= 1 && num < 10 {
            
            return "0\(num)"
            
        }
        
        return "\(num)"
        
    }
    
    // The exact character set HTMLString's addingUnicodeEntities() escapes. SbXmlParser applies it
    // to the `program`, `course` and author `name` attributes, so these are the only characters that
    // can legitimately appear as a decimal entity in one of those fields.
    private static let entityEscapedCharacters: Set<Character> = ["!", "\"", "$", "%", "&", "'", "+", ",", "<", "=", ">", "@", "[", "]", "`", "{", "}"]

    private static let decimalEntityRegex = try? NSRegularExpression(pattern: "&#(\\d{1,4});")

    // Older versions of SbXmlParser escaped the setup attributes as they *parsed* them, and escaped
    // them again when writing the XML back out, so every save/open cycle re-encoded what the last
    // one produced: a comma in an author name was written as "&#44;", read back as the literal text
    // "&#44;", and written out again as "&#38;#44;" — growing with each save until the field was
    // unreadable. Undo that here, so the model holds the plain text the user typed.
    //
    // Only the decimal entities that escaping could have produced are decoded, so text the user
    // actually typed — an "&amp;" they want kept verbatim, say — survives untouched. The pass
    // repeats until the string stops changing, which unwinds a field that has already been through
    // several saves.
    func decodingXmlAttributeEntities(_ string: String) -> String {

        guard let regex = Util.decimalEntityRegex else { return string }

        var current = string

        // A field damaged by N saves needs N passes; the bound only guards against pathological
        // input, it isn't an expected limit.
        for _ in 0 ..< 16 {

            let source = current as NSString
            let matches = regex.matches(in: current, range: NSRange(location: 0, length: source.length))

            guard !matches.isEmpty else { break }

            var result = ""
            var cursor = 0
            var changed = false

            for match in matches {

                guard let code = UInt32(source.substring(with: match.range(at: 1))),
                      let scalar = Unicode.Scalar(code),
                      Util.entityEscapedCharacters.contains(Character(scalar)) else { continue }

                result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                result.append(Character(scalar))

                cursor = match.range.location + match.range.length
                changed = true

            }

            guard changed else { break }

            result += source.substring(from: cursor)
            current = result

        }

        return current

    }

    // ".jpeg" and ".jpg" are the same format, so the packager stores page images under a single
    // canonical extension. Without this a document could end up split between the two spellings —
    // every lookup builds a filename from the document's page image format, so a slide saved with
    // the other spelling is invisible to the editor and gets swept as an orphan on the next save.
    func canonicalImageExt(_ ext: String) -> String {

        let lowered = ext.lowercased()
        return lowered == FileExtensions.JPEG ? FileExtensions.JPG : lowered

    }

    // Whether two image extensions name the same format (i.e. jpg/jpeg).
    func sameImageFormat(_ a: String, _ b: String) -> Bool {
        return canonicalImageExt(a) == canonicalImageExt(b)
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
        
        do {
            
            let wRegex = try NSRegularExpression(pattern: #"width="\d*(.\d*)?([a-z]*)?""#, options: .caseInsensitive)
            let wMatch = wRegex.firstMatch(in: svg, options: [], range: NSRange(svg.startIndex..., in: svg))
            
            if let wFirstMatch = wMatch?.range {

                let range = Range(wFirstMatch, in: svg)
                svg = svg.replacingCharacters(in: range!, with: "width=\"100%\"")

            }
            
            let hRegex = try NSRegularExpression(pattern: #"height="\d*(.\d*)?([a-z]*)?""#, options: .caseInsensitive)
            let hMatch = hRegex.firstMatch(in: svg, options: [], range: NSRange(svg.startIndex..., in: svg))
            
            if let hFirstMatch = hMatch?.range {
                
                let range = Range(hFirstMatch, in: svg)
                svg = svg.replacingCharacters(in: range!, with: "heght=\"100%\" preserveAspectRatio=\"xMinYMid meet\"")
                
            }
            
        } catch let error as NSError {
            NSLog(error.localizedDescription)
        }
        
        return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\" /><style>html{width:100%;height:100%;overflow:hidden;}body{margin:0;padding:0;width:100%;height:100%;}</style></head><body oncontextmenu=\"return false;\">\(svg)</body></html>"
        
    }
    
    func formatImgHtml(base64: String) -> String {
        
        return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\" /><style>html{width:100%;height:100%;overflow:hidden;}body{margin:0;padding:0;width:100%;height:100%;}img{display:block;width:100%;height:100%;}</style></head><body oncontextmenu=\"return false;\"><img src=\"data:image/png;base64,\(base64)\" /></body></html>"
        
    }
    
    func fileExistAt(url: URL, completion: @escaping (Bool) -> Void) {
        
        let checkSession = Foundation.URLSession.shared
        var request = URLRequest(url: url)
        
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3.0
        
        let task = checkSession.dataTask(with: request as URLRequest, completionHandler: {(data, response, error) -> Void in
            if let httpResp: HTTPURLResponse = response as? HTTPURLResponse {
                completion(httpResp.statusCode == 200)
            }
        })
        
        task.resume()
        
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
        
        let total = Int(timeInterval)
        let seconds = total % 60
        let minutes = (total / 60) % 60
        let hours = total / 3600
        
        // Past the hour this wrapped instead of growing a field: 61:40 came out "01:40", which reads
        // as a moment earlier than the frame before it. A bundle frame list that has to ascend was
        // scrambled by nothing worse than a long narration. timeStringToSeconds reads both forms.
        if hours > 0 {
            return String(format: "%0.2d:%0.2d:%0.2d", hours, minutes, seconds)
        }
        
        return String(format: "%0.2d:%0.2d", minutes, seconds)
        
    }
    
    // Frame timecodes carry hundredths when they need them: a frame pinned to a word in the
    // narration lands between seconds far more often than on one. A whole second still writes as
    // plain mm:ss, so existing presentations are untouched — and so is the exact "00:00" string the
    // parser looks for when it decides which frame opens a slide. The player reads both: its
    // toSeconds() splits on ":" and runs the parts through Number(), which takes a decimal.
    func preciseTimeAsString(timeInterval: TimeInterval) -> String {
        
        let hundredths = Int((timeInterval * 100).rounded())
        let total = hundredths / 100
        let fraction = hundredths % 100
        
        let seconds = total % 60
        let minutes = (total / 60) % 60
        let hours = total / 3600
        
        var stamp = hours > 0
            ? String(format: "%0.2d:%0.2d:%0.2d", hours, minutes, seconds)
            : String(format: "%0.2d:%0.2d", minutes, seconds)
        
        if fraction != 0 {
            stamp += String(format: ".%0.2d", fraction)
        }
        
        return stamp
        
    }
    
    /// A frame's timecode with nothing left out: minutes, seconds, and hundredths, always.
    ///
    /// This is for reading a list of them, where the compact forms make a ragged column. Frames run
    /// to the length of a slide's narration, so there is no hours field — the minutes simply keep
    /// counting, and an hour in reads as "61:40.00" rather than wrapping back to "01:40" and
    /// sorting above the frame before it.
    ///
    /// A display form only: frames are still stored the way preciseTimeAsString writes them, which
    /// is what the player reads and what "00:00" as the opening frame depends on.
    func fullTimeAsString(timeInterval: TimeInterval) -> String {

        let hundredths = Int((timeInterval * 100).rounded())
        let total = hundredths / 100

        return String(format: "%0.2d:%0.2d.%0.2d", total / 60, total % 60, hundredths % 100)

    }

    /// The same, starting from a stored timecode rather than a number of seconds.
    func fullTimecode(from stored: String) -> String {
        return fullTimeAsString(timeInterval: timeStringToSeconds(time: stored))
    }

    func timeStringToSeconds(time: String) -> Double {
        
        let parts = time.split(separator: ":")
        guard parts.count >= 2 && parts.count <= 3 else { return 0.0 }
        
        var h: Double = 0.0
        var m: Double = 0.0
        var s: Double = 0.0
        
        // Read straight through, decimals included. The seconds field used to be truncated to its
        // first two characters whenever it began "00", which turned a timecode of "00:00.50" into
        // zero — and every field was force-unwrapped, so a malformed timecode brought the app down
        // rather than reading as nothing.
        if parts.count == 2 {
            
            m = Double(parts[0]) ?? 0
            s = Double(parts[1]) ?? 0
            
        } else if parts.count == 3 {
            
            h = Double(parts[0]) ?? 0
            m = Double(parts[1]) ?? 0
            s = Double(parts[2]) ?? 0
            
        }
        
        // Hours are 3600 seconds, not 60. Typing "01:00:00" into a frame's timecode read back as one
        // minute, so the frame landed almost an hour early and the list went out of order.
        return (h * 3600) + (m * 60) + (s)
        
    }
    
    func sanitizeTime(timecode: String) -> String {
        return preciseTimeAsString(timeInterval: timeStringToSeconds(time: timecode) )
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
        
        if let regex = try? NSRegularExpression(pattern: "(\\d*-?\\d*)$", options: NSRegularExpression.Options.caseInsensitive) {
            let matched = regex.matches(in: string, range: NSRange(location: 0, length:  string.count))
            num = matched.map{ String(string[Range($0.range, in: string)!]) }.joined()
        }
        
        let numArray = num.split(separator: "-")

        // A name with no trailing digits ("captions.srt") matches the regex as an empty string and
        // splits to nothing — reading numArray[0] here used to trap and take the app down with it.
        // An empty result means "this file names no page", which every caller has to handle anyway.
        guard !numArray.isEmpty else { return "" }

        if numArray[0].count == 1 {
            
            num = leadingZero(string: String(numArray[0]))
            
        } else {
            
            num = String(numArray[0])
            
        }
        
        if numArray.indices.contains(1) {
            num = num + "-" + numArray[1]
        }
        
        return num
        
    }
    
    func leadingZero(string: String) -> String {
        
        if string.count == 1 {
            return "0" + string
        }
        
        return string
        
    }
    
    func getFileNameParts(file: String) -> (String, String, String) {
        
        var fileName: (String, String, String) = ("", "", "")
        var nameArray = file.split(separator: ".")
        
        nameArray = nameArray[0].split(separator: "-")
        
        if nameArray.count >= 1 {
            fileName.0 = String(nameArray[0])
            fileName.1 = parseNumFromFileName(string: fileName.0)
        }
        
        if nameArray.indices.contains(1) {
            fileName.2 = String(nameArray[1])
        }
        
        return fileName
        
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
