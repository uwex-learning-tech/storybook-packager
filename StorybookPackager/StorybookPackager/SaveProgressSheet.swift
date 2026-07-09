//
//  SaveProgressSheet.swift
//  StorybookPackager
//
//  A lightweight modal sheet shown over the document window while a save is in progress.
//

import Cocoa

// Besides giving the user feedback during long saves of asset-heavy presentations, this sheet
// blocks interaction with the document window for the duration of the save — which is what makes
// asynchronous writing safe. While the package is being written to disk on a background queue (see
// Document.canAsynchronouslyWrite / write(to:ofType:for:originalContentsURL:)), the user must not be
// able to mutate the in-memory model or asset wrappers; the sheet enforces that.
//
// The bar starts indeterminate (the brief in-memory "prepare" phase, which has no measurable unit)
// and switches to a real, determinate bar once the disk write begins reporting bytes written.
//
// begin()/end() are ref-counted so nested or back-to-back saves (e.g. saveAs followed by an
// automatic re-save) show and tear down the sheet exactly once.
final class SaveProgressSheet {

    private let window: NSWindow
    private let bar: NSProgressIndicator
    private let label: NSTextField
    private weak var host: NSWindow?
    private var activeCount = 0

    init() {

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 92))

        label = NSTextField(labelWithString: "Saving…")
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingMiddle
        label.frame = NSRect(x: 20, y: 52, width: 320, height: 18)
        content.addSubview(label)

        bar = NSProgressIndicator(frame: NSRect(x: 20, y: 28, width: 320, height: 16))
        bar.style = .bar
        bar.isIndeterminate = true
        bar.minValue = 0
        bar.maxValue = 1
        content.addSubview(bar)

        window = NSWindow(contentRect: content.frame,
                          styleMask: [.titled],
                          backing: .buffered,
                          defer: true)
        window.contentView = content
        window.isReleasedWhenClosed = false
    }

    // Present the sheet on `host` (the document window). No-op if already showing for an earlier save.
    func begin(on host: NSWindow, message: String) {

        activeCount += 1
        guard activeCount == 1 else { return }

        self.host = host
        label.stringValue = message
        bar.isIndeterminate = true
        bar.doubleValue = 0
        bar.startAnimation(nil)
        host.beginSheet(window, completionHandler: nil)

    }

    // Advance the bar. `fraction` is 0...1. Must be called on the main thread. The first call flips
    // the bar from its indeterminate "preparing" animation to a real determinate bar.
    func update(fraction: Double) {

        if bar.isIndeterminate {
            bar.stopAnimation(nil)
            bar.isIndeterminate = false
        }
        bar.doubleValue = min(1, max(0, fraction))

    }

    // Dismiss the sheet once the matching number of end() calls have arrived.
    func end() {

        guard activeCount > 0 else { return }
        activeCount -= 1
        guard activeCount == 0 else { return }

        bar.stopAnimation(nil)
        host?.endSheet(window)
        host = nil

    }
}
