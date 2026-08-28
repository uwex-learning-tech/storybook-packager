//
//  SlideImageFormatSwitchPrompt.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  Changing a presentation's slide image format is a change to every slide it holds, not to a
//  setting — the format is half of every filename under assets/pages/. It used to happen silently,
//  in Properties, and the next save swept every slide image out of the package. So it is asked once,
//  in plain language, and when a slide cannot follow the presentation into the new format the alert
//  names it rather than letting it disappear.
//
//  Three different actions reach this question — a batch dropped on the page list, one image chosen
//  for one slide, and the Page Image Type popup in Properties — and each has to be described as the
//  thing the author actually did. A first cut wrote "the slide images the import doesn't cover" for
//  all three, which told someone who had just changed a popup in Properties about an import that
//  wasn't happening, and someone who had picked a single file that they had run one.
//

import Cocoa

enum SlideImageFormatSwitchPrompt {

    /// What the author did to get here. It decides how the change is described, nothing else.
    enum Context {

        /// A batch of images dropped on the page list.
        case importing

        /// One image chosen for one slide, through Set Image.
        case settingOneImage

        /// File ▸ Convert Slide Images…, where the whole point is the conversion and no images are
        /// arriving alongside it.
        case changingTheSetting

    }

    /// Which format to move to, or nil if the author backed out. Offers only the formats the
    /// presentation's images can actually be carried into — a menu command that leads to "every one
    /// of your slides loses its image" is not offering a conversion, it is offering to empty the
    /// presentation. An SVG deck has nowhere to go at all, and says so instead of opening a popup
    /// whose every entry is a dead end.
    static func chooseFormat(current: String) -> String? {

        let options = SlideImageFormat.convertibleTargets(from: current)

        guard !options.isEmpty else {

            explainNothingToConvertTo(current: current)

            return nil

        }

        let alert = NSAlert()

        alert.alertStyle = .informational
        alert.messageText = "Convert this presentation's slide images"
        alert.informativeText = "A presentation keeps all of its slide images in one format. It is currently \(current.uppercased())."

        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 160, height: 25), pullsDown: false)
        popUp.addItems(withTitles: options.map { $0.uppercased() })

        alert.accessoryView = popUp

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        return options.indices.contains(popUp.indexOfSelectedItem) ? options[popUp.indexOfSelectedItem] : nil

    }

    /// There is no format this presentation's slide images can be moved to — it is in SVG, and
    /// nothing turns a drawing back out of a picture (Conversion.impossible). Said plainly, with the
    /// one way forward, rather than leaving a menu command that does nothing when chosen.
    static func explainNothingToConvertTo(current: String) {

        let alert = NSAlert()

        alert.alertStyle = .informational
        alert.messageText = "These slide images can't be converted."
        alert.informativeText = "This presentation's slide images are \(current.uppercased()) drawings, and nothing can turn a drawing into a picture without redrawing it. To move the presentation to PNG or JPG, re-export the slides from whatever made them and drag the new images onto the page list."

        alert.addButton(withTitle: "OK")

        alert.runModal()

    }

    /// Ask whether to move the presentation to `plan.to`. False means nothing happens at all — no
    /// format change, and no import either.
    static func confirm(_ plan: SlideImageFormat.SwitchPlan, context: Context) -> Bool {

        // Nothing to weigh: the presentation holds no images in the old format, so this is a
        // setting change with nothing at stake. Asking would be a dialog whose own text says there
        // is nothing to convert.
        guard !(plan.replaced.isEmpty && plan.converted.isEmpty && plan.lost.isEmpty) else { return true }

        let alert = NSAlert()

        alert.alertStyle = plan.lost.isEmpty ? .informational : .warning
        alert.messageText = "Change this presentation's slide images to \(plan.to.uppercased())?"
        alert.informativeText = informative(for: plan, context: context)

        // Cancel is second so Escape picks it.
        alert.addButton(withTitle: "Switch")
        alert.addButton(withTitle: "Cancel")

        // When slides are lost the switch cannot be taken back by pressing the button again, so it
        // is marked destructive and gives up the Return key — nothing irreversible should be one
        // reflexive keystroke away. Cancel keeps the Escape key it gets from its title.
        if !plan.lost.isEmpty {
            alert.buttons[0].hasDestructiveAction = true
            alert.buttons[0].keyEquivalent = ""
        }

        // The list is only worth the space when it carries something that can't be undone by
        // pressing the button again: the images that end up with no slide at all.
        if !plan.lost.isEmpty {
            alert.accessoryView = AlertList.accessoryView(for: plan.lost)
        }

        return alert.runModal() == .alertFirstButtonReturn

    }

    /// What the switch does, said in the order it happens.
    static func informative(for plan: SlideImageFormat.SwitchPlan, context: Context) -> String {

        let from = plan.from.uppercased()
        let to = plan.to.uppercased()

        var sentences = ["A presentation keeps all of its slide images in one format, so this sets the whole presentation to \(to)."]

        // Said whenever there is something arriving, not only when it lands on a slide that already
        // had an image. Gating it on `replaced` meant that dropping images for slides that had none
        // yet — a perfectly ordinary import — skipped it, which both lost the reassurance and left
        // the "other" in the next sentence with nothing to be other than.
        switch context {

        case .importing:
            sentences.append(plan.incoming == 1
                ? "The image you are importing goes in as it is."
                : "The images you are importing go in as they are.")

        case .settingOneImage:
            sentences.append("The image you chose goes in as it is.")

        case .changingTheSetting:
            break

        }

        if !plan.converted.isEmpty {

            let count = plan.converted.count
            let images = count == 1 ? "1 slide image" : "\(count) slide images"

            switch context {

            case .importing:
                sentences.append("The \(images) the import doesn't cover \(count == 1 ? "is" : "are") converted from \(from) to \(to).")

            case .settingOneImage:
                sentences.append(count == 1
                    ? "The presentation's one other slide image is converted from \(from) to \(to)."
                    : "The presentation's other \(count) slide images are converted from \(from) to \(to).")

            case .changingTheSetting:
                sentences.append(count == 1
                    ? "Its 1 slide image is converted from \(from) to \(to)."
                    : "All \(count) of its slide images are converted from \(from) to \(to).")

            }

        }

        if !plan.lost.isEmpty {

            let count = plan.lost.count

            sentences.append(count == 1
                ? "Nothing can turn a picture back into a drawing, so the image listed below cannot come with the presentation and that slide is left without one."
                : "Nothing can turn a picture back into a drawing, so the \(count) images listed below cannot come with the presentation and those slides are left without one.")

        }

        // Last, because it is what the other button does. Cancelling abandons the whole drop, not
        // just the format change — including any audio or captions that came with it — and the only
        // other thing saying so is the word on the button.
        if case .importing = context {
            sentences.append("Cancel imports nothing at all.")
        }

        return sentences.joined(separator: " ")

    }

    /// Some images could not be converted, after the work was done. Nothing has been written yet, so
    /// this is still a real choice: Cancel leaves the presentation exactly as it was.
    ///
    /// This is the failure the plan could not predict — an SVG WebKit declines to draw, a file that
    /// isn't the image its name claims. Without it the switch went ahead regardless and the author
    /// watched a progress bar complete while their slides were emptied.
    static func confirmFailures(_ failed: Array<String>,
                                from: String,
                                to: String,
                                context: Context = .changingTheSetting) -> Bool {

        let alert = NSAlert()

        alert.alertStyle = .warning
        alert.messageText = failed.count == 1
            ? "1 slide image could not be converted to \(to.uppercased())."
            : "\(failed.count) slide images could not be converted to \(to.uppercased())."

        alert.informativeText = failureInformative(count: failed.count, from: from, context: context)

        alert.addButton(withTitle: "Switch Anyway")
        alert.addButton(withTitle: "Cancel")

        // This alert only ever appears once conversions are known to have failed, so proceeding
        // knowingly drops those images. Destructive, and not the Return-key default. Cancel keeps
        // the Escape key it gets from its title.
        alert.buttons[0].hasDestructiveAction = true
        alert.buttons[0].keyEquivalent = ""

        alert.accessoryView = AlertList.accessoryView(for: failed)

        return alert.runModal() == .alertFirstButtonReturn

    }

    /// What the two buttons on the failure alert do. Extracted so it can be read back in a test —
    /// this text makes a promise about Cancel, and the promise has to match what the caller does
    /// with the answer.
    static func failureInformative(count: Int, from: String, context: Context) -> String {

        var sentences = [count == 1
            ? "The image listed below could not be read as \(from.uppercased()), so it cannot come with the presentation and that slide would be left without one."
            : "The images listed below could not be read as \(from.uppercased()), so they cannot come with the presentation and those slides would be left without one."]

        // Cancelling here refuses the format change, and every caller drops what it was going to do
        // on the back of it. Saying only that the presentation is left alone would be true and
        // still misleading: the batch the first question promised would "go in as they are" does
        // not go in.
        switch context {

        case .importing:
            sentences.append("Cancel leaves the presentation as it is, still in \(from.uppercased()), and imports nothing.")

        case .settingOneImage:
            sentences.append("Cancel leaves the presentation as it is, still in \(from.uppercased()), and the image you chose is not set.")

        case .changingTheSetting:
            sentences.append("Cancel leaves the presentation as it is, still in \(from.uppercased()).")

        }

        return sentences.joined(separator: " ")

    }

}
