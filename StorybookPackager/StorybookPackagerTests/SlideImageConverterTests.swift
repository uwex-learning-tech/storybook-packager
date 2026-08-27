//
//  SlideImageConverterTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  Converting a slide image is a one-way change to the author's artwork: the presentation moves to
//  the new format and the original file goes with it. Only raster formats convert — SVG in either
//  direction is refused — so what is pinned here is the re-encode, plus the HTML the SVG preview is
//  built from, which shares the tag-finding this file's fixes came out of.
//

import XCTest
import AppKit

class SlideImageConverterTests: XCTestCase {

    // Always RGBA: Core Graphics has no 24-bit backing store, so a bitmap declared without alpha
    // can't back a context to draw into. An opaque fill colour is what makes the image opaque.
    private func pngData(width: Int, height: Int, color: NSColor) -> Data {

        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: width,
                                   pixelsHigh: height,
                                   bitsPerSample: 8,
                                   samplesPerPixel: 4,
                                   hasAlpha: true,
                                   isPlanar: false,
                                   colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0,
                                   bitsPerPixel: 0)!

        let context = NSGraphicsContext(bitmapImageRep: rep)!

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])!

    }

    func testAPngRoundTripsThroughJpgAndBack() {

        let png = pngData(width: 24, height: 16, color: .red)

        guard let jpg = SlideImageConverter.transcode(png, to: FileExtensions.JPG) else {
            return XCTFail("a PNG should transcode to JPG")
        }

        guard let back = SlideImageConverter.transcode(jpg, to: FileExtensions.PNG),
              let rep = NSBitmapImageRep(data: back) else {
            return XCTFail("a JPG should transcode back to PNG")
        }

        XCTAssertEqual(rep.pixelsWide, 24)
        XCTAssertEqual(rep.pixelsHigh, 16)

    }

    // JPEG has no alpha, and an un-composited transparent PNG encodes as black wherever it was
    // see-through — which is most of a slide exported with no background.
    func testATransparentPngBecomesAnOpaqueWhiteBackedJpg() {

        let png = pngData(width: 8, height: 8, color: NSColor.clear)

        guard let jpg = SlideImageConverter.transcode(png, to: FileExtensions.JPG),
              let rep = NSBitmapImageRep(data: jpg),
              let pixel = rep.colorAt(x: 4, y: 4) else {
            return XCTFail("a transparent PNG should transcode to an opaque JPG")
        }

        XCTAssertFalse(rep.hasAlpha)

        // White, not the black an un-composited transparent PNG encodes as.
        XCTAssertEqual(pixel.redComponent, 1, accuracy: 0.05)
        XCTAssertEqual(pixel.greenComponent, 1, accuracy: 0.05)
        XCTAssertEqual(pixel.blueComponent, 1, accuracy: 0.05)

    }

    func testNothingTranscodesToSvg() {

        let png = pngData(width: 4, height: 4, color: .blue)

        XCTAssertNil(SlideImageConverter.transcode(png, to: FileExtensions.SVG))

    }

    // The realistic failure in the field: a file that isn't the image its name claims, or one that
    // arrived truncated. It has to come back nil so the caller reports it and keeps the original,
    // rather than writing whatever the encoder made of the garbage over a slide.
    func testUnreadableBytesConvertToNothing() {

        XCTAssertNil(SlideImageConverter.transcode(Data(), to: FileExtensions.JPG))
        XCTAssertNil(SlideImageConverter.transcode(Data("not an image at all".utf8), to: FileExtensions.PNG))

        // A PNG header with the rest of the file missing — the shape a half-copied asset takes.
        let truncated = pngData(width: 8, height: 8, color: .red).prefix(16)
        XCTAssertNil(SlideImageConverter.transcode(Data(truncated), to: FileExtensions.JPG))

    }

    // SVG is the target this app can actually ask for and be refused, but the refusal is not special
    // to SVG: anything that isn't one of the two raster formats has to be turned away. Pinned so a
    // later narrowing of that switch to just SVG doesn't quietly start encoding PNG bytes under a
    // .gif name.
    func testUnknownTargetFormatsConvertToNothing() {

        let png = pngData(width: 4, height: 4, color: .blue)

        XCTAssertNil(SlideImageConverter.transcode(png, to: "gif"))
        XCTAssertNil(SlideImageConverter.transcode(png, to: "webp"))
        XCTAssertNil(SlideImageConverter.transcode(png, to: ""))

    }

    // MARK: - the HTML an SVG slide is previewed through

    // formatSvg used to replace the first width= and height= it found ANYWHERE in the document. On a
    // viewBox-only export — no size on the root at all, which is what a "responsive" SVG is — that
    // landed on the first shape inside, and the misspelled "heght" it wrote left that shape with no
    // height, so it drew nothing. A blank preview became a blank exported image once this fed the
    // format conversion, and the original SVG was removed on the strength of it.
    func testOnlyTheRootTagIsResized() {

        let source = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1280 720\"><rect width=\"1280\" height=\"720\"/></svg>"

        let html = Util.shared.formatSvg(str: source)

        XCTAssertTrue(html.contains("<rect width=\"1280\" height=\"720\"/>"))
        XCTAssertFalse(html.contains("heght"))

    }

    func testTheRootTagsOwnSizeIsMadeToFit() {

        let source = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"960\" height=\"540\"><rect width=\"10\" height=\"10\"/></svg>"

        let html = Util.shared.formatSvg(str: source)

        XCTAssertTrue(html.contains("width=\"100%\""))
        XCTAssertTrue(html.contains("height=\"100%\""))
        XCTAssertTrue(html.contains("<rect width=\"10\" height=\"10\"/>"))

    }

    func testAStrokeWidthOnTheRootIsNotStretchedToFit() {

        let source = "<svg xmlns=\"http://www.w3.org/2000/svg\" stroke-width=\"2\" width=\"24\" height=\"24\"></svg>"

        let html = Util.shared.formatSvg(str: source)

        XCTAssertTrue(html.contains("stroke-width=\"2\""))

    }


    // A commented-out decoy above the real root is not the root: the rewrite used to land inside the
    // comment while the artwork itself went untouched.
    func testADecoySvgInACommentIsNotTheRoot() {

        let source = "<!-- <svg width=\"1\"> --><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"960\" height=\"540\"></svg>"

        let html = Util.shared.formatSvg(str: source)

        XCTAssertTrue(html.contains("<!-- <svg width=\"1\"> -->"))
        XCTAssertTrue(html.contains("width=\"100%\""))

    }

    func testAnXmlDeclarationAndDoctypeAreNotTheRoot() {

        let html = Util.shared.formatSvg(str: "<?xml version=\"1.0\"?><!DOCTYPE svg><svg width=\"800\" height=\"600\"></svg>")

        XCTAssertTrue(html.contains("<svg width=\"100%\" height=\"100%\""))

    }

    // Dropping only the ">" left the "/" of a self-closing root stranded between attributes, and an
    // <svg/> that stops being self-closing swallows the rest of the document as part of the drawing.
    func testASelfClosingRootStaysSelfClosing() {

        let html = Util.shared.formatSvg(str: "<svg viewBox=\"0 0 10 10\"/>")

        XCTAssertFalse(html.contains("/ preserveAspectRatio"))
        XCTAssertTrue(html.contains("preserveAspectRatio=\"xMidYMid meet\"/>"))

    }

    // The stylesheet sizes the root; a nested <svg> is a sub-viewport whose own geometry is part of
    // the drawing, and blowing it up to the full canvas scrambles the artwork.
    func testOnlyTheRootSvgIsSizedByTheStylesheet() {

        let html = Util.shared.formatSvg(str: "<svg width=\"96\" height=\"54\"><svg x=\"10\" y=\"10\" width=\"20\" height=\"20\"></svg></svg>")

        XCTAssertTrue(html.contains("body>svg{"))
        XCTAssertTrue(html.contains("<svg x=\"10\" y=\"10\" width=\"20\" height=\"20\">"))

    }

}
