//
//  SlideTitleOCR.swift
//  Storybook Packager
//
//  Copyright © 2026 University of Wisconsin System. All rights reserved.
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
    }

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
                                    box: observation.boundingBox)
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

    /// Picks the topmost line as the title. Vision boxes are normalized with a bottom-left origin,
    /// so "topmost" means the largest maxY. Vision often splits one visual line into several boxes;
    /// boxes whose vertical centers sit within 0.6× the topmost box's height are treated as the
    /// same line and joined left to right.
    static func titleCandidate(from lines: [TextLine]) -> String? {

        let confident = lines.filter {
            $0.confidence >= 0.4 && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
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
