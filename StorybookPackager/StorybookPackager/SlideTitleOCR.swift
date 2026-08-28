//
//  SlideTitleOCR.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import Cocoa
import Vision

/// Guesses a slide's title by running the built-in Vision OCR over the slide image and picking
/// the topmost line of text.
enum SlideTitleOCR {

    enum Source {
        case data(Data)
        case cgImage(CGImage)
    }

    enum OCRError: Error {
        case noText
        case badImage
    }

    /// A recognized line of text with its normalized bounding box. VNRecognizedTextObservation
    /// can't be fabricated in tests, so the title heuristic runs on this plain value type instead.
    struct TextLine {

        let text: String
        let confidence: Float
        let box: CGRect

        /// Degrees off horizontal. A slide title is level; the label up the side of a chart is not.
        let angle: CGFloat

        init(text: String, confidence: Float, box: CGRect, angle: CGFloat = 0) {
            self.text = text
            self.confidence = confidence
            self.box = box
            self.angle = angle
        }

    }

    /// How far off level a line may sit and still be read as a title. Generous enough for the
    /// slight tilt Vision reports on a line it has fitted loosely, nowhere near a rotated label.
    static let maxTitleTilt: CGFloat = 15

    /// Recognition is bounded to a few images at a time: a bulk import can queue 60+ requests in
    /// one loop, and running them all on the global queue blocks a GCD worker thread per image
    /// inside `perform()` — enough to exhaust the thread pool and wedge the app.
    private static let recognitionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "edu.uwex.media.StorybookPackager.SlideTitleOCR"
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .userInitiated
        return queue
    }()

    /// Runs text recognition on a background queue and calls back on the main queue with either
    /// the title guess or an error (`OCRError.noText` when the slide has no usable text).
    /// (`Swift.Result` spelled out because the app declares its own `Result` struct.)
    static func guessTitle(from source: Source, completion: @escaping (Swift.Result<String, Error>) -> Void) {

        recognitionQueue.addOperation {

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler: VNImageRequestHandler
            switch source {
            case .data(let data):
                handler = VNImageRequestHandler(data: data, options: [:])
            case .cgImage(let image):
                handler = VNImageRequestHandler(cgImage: image, options: [:])
            }

            let result: Swift.Result<String, Error>

            do {

                try handler.perform([request])

                let observations: [VNRecognizedTextObservation] = request.results ?? []
                let lines = observations.compactMap { observation -> TextLine? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return TextLine(text: candidate.string,
                                    confidence: candidate.confidence,
                                    box: observation.boundingBox,
                                    angle: tilt(of: observation))
                }

                if let title = titleCandidate(from: lines) {
                    result = .success(title)
                } else {
                    result = .failure(OCRError.noText)
                }

            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async { completion(result) }

        }

    }

    /// How far off level a recognized line sits, in degrees, taken from the top edge of the
    /// quadrilateral Vision fits to it. `boundingBox` is axis-aligned and cannot tell a rotated line
    /// from a level one: the label running up the side of a diagram arrives as a box taller than the
    /// title and higher up the slide, which is enough to win on both of the tests below.
    ///
    /// Measured in Vision's normalized space, where the two axes are not to the same scale unless
    /// the slide is square. That skews the reported angle of a genuinely diagonal line, and does not
    /// matter for what this is for: level and upright stay 0 and 90 whatever the shape of the slide.
    private static func tilt(of observation: VNRecognizedTextObservation) -> CGFloat {

        let left = observation.topLeft
        let right = observation.topRight

        return atan2(right.y - left.y, right.x - left.x) * 180 / .pi

    }

    /// Whether a slide's title is one the app wrote rather than one its author typed.
    ///
    /// Every placeholder the app writes is wrapped in square brackets: "[Untitled]" for a slide
    /// added from the outline, and the file's own name in brackets for one a bulk import created.
    /// A title outside brackets is somebody's own words, and a guess read off the image is not an
    /// improvement on it — so the automatic pass leaves it alone. Choosing Guess Title from the
    /// menu is a deliberate act and replaces anything.
    static func isPlaceholderTitle(_ title: String) -> Bool {

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty { return true }

        return trimmed.hasPrefix("[") && trimmed.hasSuffix("]")

    }

    /// Picks the topmost line as the title. Vision boxes are normalized with a bottom-left origin,
    /// so "topmost" means the largest maxY. Vision often splits one visual line into several boxes;
    /// boxes whose vertical centers sit within 0.6× the topmost box's height are treated as the
    /// same line and joined left to right.
    static func titleCandidate(from lines: [TextLine]) -> String? {

        // Rotated lines go before anything is measured, not after. Left in, the tall narrow box of
        // a label set up the side of a diagram becomes the tallest line on the slide, which lifts
        // the size floor below and throws the real title out with the footnotes.
        let confident = lines.filter {
            $0.confidence >= 0.4
                && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
                && abs($0.angle) <= maxTitleTilt
        }

        guard let tallest = confident.map({ $0.box.height }).max() else { return nil }

        // Titles are usually the largest text on the slide; drop footnote-sized lines so a header
        // or course code above the title doesn't win on position alone.
        let sized = confident.filter { $0.box.height >= tallest * 0.4 }

        let byTop = sized.sorted { $0.box.maxY > $1.box.maxY }
        guard let first = byTop.first else { return nil }

        let sameLine = byTop
            .filter { abs($0.box.midY - first.box.midY) <= first.box.height * 0.6 }
            .sorted { $0.box.minX < $1.box.minX }

        let title = sameLine.map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return title.isEmpty ? nil : title

    }

}
