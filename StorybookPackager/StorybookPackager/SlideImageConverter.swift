//
//  SlideImageConverter.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  Re-encoding a slide image from one raster format to the other. That is the whole of it: PNG to
//  JPEG and back, synchronously, in memory.
//
//  It briefly also rasterized SVG through an off-screen WKWebView. That worked, but it made the
//  conversion asynchronous, and an asynchronous mutation of the document's file wrappers is a thing
//  this app has nowhere else — it needed a progress sheet, a queue to hold saves that arrived
//  mid-flight, and a second queue for saves already in flight, and it still let the plan the author
//  approved go stale behind them. It was also the only code here doing its own SVG measuring, its
//  own CSS unit arithmetic and its own text-encoding guesswork. SlideImageFormat.Conversion now
//  calls SVG conversion impossible in both directions and the author is told which slides to
//  re-export, which is a smaller promise the packager can actually keep.
//

import Cocoa

enum SlideImageConverter {

    // MARK: - raster to raster

    /// Re-encode image bytes as `ext`. Nil when the bytes aren't a readable bitmap, or `ext` isn't a
    /// raster format (nothing turns a photograph back into vector artwork).
    static func transcode(_ data: Data, to ext: String) -> Data? {

        guard let rep = NSBitmapImageRep(data: data) else { return nil }

        return encode(rep, to: ext)

    }

    /// Encode a bitmap as `ext`, flattening transparency first when the destination has no alpha.
    static func encode(_ rep: NSBitmapImageRep, to ext: String) -> Data? {

        switch Util.shared.canonicalImageExt(ext) {

        case FileExtensions.PNG:
            return rep.representation(using: .png, properties: [:])

        case FileExtensions.JPG:
            // JPEG has no alpha at all, and an un-composited transparent PNG encodes as black
            // wherever it was see-through — which is most of a slide exported with no background.
            guard let opaque = compositedOntoWhite(rep) else { return nil }
            return opaque.representation(using: .jpeg, properties: [.compressionFactor: 0.9])

        default:
            return nil

        }

    }

    /// The same pixels over a white background. Returns the rep unchanged when it has no alpha.
    private static func compositedOntoWhite(_ rep: NSBitmapImageRep) -> NSBitmapImageRep? {

        guard rep.hasAlpha else { return rep }

        // Kept RGBA rather than RGB: Core Graphics has no 24-bit backing store, so a bitmap
        // declared without alpha can't back a context to draw into at all. Every pixel is painted
        // opaque white below, and the JPEG encoder drops the channel on the way out.
        guard let flattened = NSBitmapImageRep(bitmapDataPlanes: nil,
                                               pixelsWide: rep.pixelsWide,
                                               pixelsHigh: rep.pixelsHigh,
                                               bitsPerSample: 8,
                                               samplesPerPixel: 4,
                                               hasAlpha: true,
                                               isPlanar: false,
                                               colorSpaceName: .deviceRGB,
                                               bytesPerRow: 0,
                                               bitsPerPixel: 0) else { return nil }

        flattened.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)

        guard let context = NSGraphicsContext(bitmapImageRep: flattened) else { return nil }

        let bounds = NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        NSColor.white.setFill()
        bounds.fill()
        rep.draw(in: bounds)

        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        return flattened

    }

}
