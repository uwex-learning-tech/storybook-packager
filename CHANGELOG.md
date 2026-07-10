# Changelog

All notable changes to Storybook Packager are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

User-facing release notes for Sparkle auto-update live in
`StorybookPackager/updates/` and are mirrored here at release time.

## [Unreleased]

### Added
- The title tools now live in the Edit menu too: Apply Title Case (⇧⌘T) and Guess Title from Slide Image (⇧⌘O) work no matter where focus is, and are greyed out when they don't apply.

### Changed
- The release year prompt shown when saving a presentation that has no year can no longer be dismissed without choosing one. The Cancel button is gone — the prompt opens on the current year, so the worst case is accepting it — and the explanation of what the year is used for has been dropped in favor of simply saying one is required.
- The "Aa" title case and "OCR" guess-title controls beside the page title are now real bordered buttons. They used to be bare icons that read as dimmed status indicators rather than something clickable.

### Removed
- The confirm-placeholder-title button (the yellow checkmark that appeared beside bracketed titles like "[Untitled]" in the title field, page list, and Touch Bar) is gone. With OCR filling in slide titles automatically, placeholder titles no longer pile up, and the checkmark's only trick — stripping the brackets — wasn't worth the confusion.

### Fixed
- The release year chosen when first saving a new presentation is now actually stored. It was discarded moments after being set, so the presentation was written without a year and the Properties dialog showed the Release Year field as unset.
- The app is now built as a universal binary and runs natively on Apple Silicon Macs. Every previous release was Intel-only — the release script built for the (Intel) build machine's architecture — so Apple Silicon Macs ran the app under Rosetta and periodically warned about it. The release script now builds both architectures and refuses to ship unless the app and every embedded framework contain both slices.

## [1.5.2] - 2026-07-09

### Fixed
- Fixed a crash when dragging in a batch of slide images while no page was selected in the page list — for example right after deleting every page in a presentation. The finished title guess tried to refresh the selected page, found none, and quit the app.
- Automatically guessed slide titles now show up as soon as they are ready. Titles filled in by a batch image import were written to the page but not drawn, so they only appeared once the page had been scrolled out of the list and back, and the title field only caught up after selecting a different page and returning.

## [1.5.1] - 2026-07-09

### Fixed
- Automatically guessed slide titles are no longer silently dropped on presentations that contain sections. The guess was matched against the wrong page counter — one that skips section headers — so once a section sat above the page you were editing, the finished guess was discarded instead of being applied to the title field.
- Automatically guessed slide titles now appear when you drag in a batch of slide images. The guess was being written to a page that had already been replaced by the import finishing, so the title never reached the page you could see.

## [1.5.0] - 2026-07-09

### Added
- A new "Automatically guess slide titles from images" option in Preferences → General (off by default) runs the same slide-title text recognition as the OCR button automatically whenever a slide image is added: dragging in a batch of jpg/png slides, setting an image on a single page, and swapping a page's existing image all fill in the title without you having to click the button. Swapping a page's image always replaces the title with the fresh guess. Bulk-imported SVG slides keep their filename-derived title until you open that page, since SVGs need to be rendered before a title can be read from them.

## [1.4.0] - 2026-07-09

### Added
- A new button at the end of the page title row reads the slide image with macOS's built-in text recognition and fills the title field with the topmost line of text on the slide — usually the slide's title. It works on Image and Image & Audio pages, including SVG slides once they have finished rendering, and the guess is inserted exactly as read so the title case button next to it can recase it if needed. If the slide has no readable text, the app says so and leaves the title alone.

## [1.3.3] - 2026-07-08

### Added
- A title case button next to the page title field recases the title the way a copy editor would: small words like "of", "and" and "the" stay lowercase in the middle of the title but are capitalized at the start and end, hyphenated compounds are handled ("In-Flight"), and spellings you intended are left alone (iPhone, HTML, Q&A, AT&T). A title typed in ALL CAPS is recased rather than left shouting. Web addresses, email addresses, file paths, and numbers are never altered.
- Saving a presentation that has no release year now asks you to choose one before the save proceeds. Storybook+ uses the release year to locate the presentation's splash image, so a presentation without one cannot display it. Cancelling the prompt cancels the save and leaves the presentation unsaved.

### Changed
- The Release Year field in the Properties dialog is now a menu of years instead of a free-text field, so it is no longer possible to type a malformed year. A presentation whose year falls outside the offered range keeps that year rather than having it silently rewritten. A presentation with no year yet shows a dash, so opening Properties never assigns a year on its own.

### Fixed
- Fixed a presentation with a release year but no course number being saved with a malformed course value. On reopening, the year was then displayed as the course number.
- Adding or deleting a choice in the Multiple Choice or Multiple Answer quiz editors while you were still typing in a choice or feedback cell no longer applies that unfinished edit to the wrong row.

## [1.3.2] - 2026-07-08

### Changed
- Text you type or paste into a presentation is now tidied up when you click away from the field: any blank lines or stray spaces at the very beginning and end are removed. This applies to quiz questions, answer choices and their feedback, page titles, page notes, HTML widget content, and the Properties dialog (title, subtitle, program, course, release year, length, general info, and author name and profile). Formatting *inside* the text — blank lines between paragraphs, indented HTML — is left exactly as you wrote it. Pasting from Word, a PDF, or a web page no longer carries invisible whitespace into the published presentation.
- A presentation title consisting only of spaces is now treated as empty, and the Properties dialog asks you to enter a real one.
- The Choices and Feedback columns in the Multiple Choice and Multiple Answer quiz editors can now be resized by dragging, and the widths you choose are remembered between launches. The columns also start out sharing the available width evenly instead of the Choices column being cramped.

### Fixed
- The Properties dialog no longer marks the presentation as edited when you press Save without actually changing anything. Previously a trailing space in a text field was enough to make every Save report unsaved changes.
- Fixed a crash on launch when macOS restored a previously open presentation window before the app's preference defaults had been registered.
- Fixed a crash when opening a presentation recovered from an autosaved draft, which has no file on disk yet.

## [1.3.1] - 2026-07-08

### Fixed
- Fixed a crash when saving a brand-new, never-saved presentation for the first time. Under the background saving added in 1.3.0 the page model wasn't ready yet at the moment of the first save; it's now seeded before use.
- Multiple Choice and Multiple Answer quiz editors are now shorter so they fit within the window: the Add/Delete choice buttons (Multiple Choice) and the correct/incorrect feedback fields (Multiple Answer) are no longer cut off at the bottom.

## [1.3.0] - 2026-07-08

### Added
- Auto-calculate the presentation **Length** from page media: a button next to the Length field in Properties opens a dialog where you set a fallback duration (default 30s) for slides that can't be measured, then estimates the total as whole minutes. Narrated/audio and local-video pages use their real durations; Vimeo (oEmbed), Kaltura (HLS), and YouTube (watch-page lookup) streaming pages are measured over the network; image-only, quiz, and HTML pages use the fallback.
- Copy sections and pages between open presentations, by drag-and-drop or Edit ▸ Copy/Paste (⌘C/⌘V). Selecting a section copies it together with all of its pages. Pasted pages are fully independent copies — they bring their own copies of every referenced asset (page images, narration and bundle audio, video, captions, quiz images/audio, and HTML widget folders) under non-colliding names, and the source presentation is never changed. Copy/paste also works within a single presentation to duplicate pages in place.
- Duplicate the selected section(s) or page(s) in place with Edit ▸ Duplicate (⌘D). The copies are independent, with their own asset files, and are inserted right after the selection.

### Changed
- Saving now shows a "Saving…" sheet with a real progress bar and writes the package to disk in the background, so the app no longer beachballs while saving large, asset-heavy presentations. Asset files that aren't being renamed are no longer duplicated in memory during a save, reducing the work and memory needed to save big projects.

### Fixed
- Caption (`.vtt`) files now stay paired with their page when pages are renumbered on save, instead of being dropped.
- Multiple Choice and Multiple Answer quiz editors no longer push their bottom controls off-screen: the Add/Delete choice buttons stay visible on Multiple Choice, and the incorrect-feedback box is no longer clipped on Multiple Answer.

## [1.2.2] - 2026-06-17

### Fixed
- Restored automatic updates, which were being rejected due to an update signing-key mismatch.

## [1.2.1] - 2026-06-17

### Fixed
- Fixed automatic updates failing to install with an "error extracting the archive" message; the update package no longer includes an Applications symlink.

## [1.2.0] - 2026-06-17

This is the first release since the 2020 beta (build 27); it consolidates everything
that has changed since then.

### Added
- Support for adding audio to quizzes (multiple choice and multiple answer quiz types).
- New Welcome window with a recent-projects list.
- Document type (UTI) registration so Storybook+ packages are recognized by the system.

### Changed
- Settings have moved into the Properties dialog.
- Refreshed the interface to use native macOS system icons throughout (toolbar, document, and network-status icons).
- Minimum supported macOS raised to 11 (Big Sur).

### Fixed
- Corrected a bug in the displayed release year.
- Prevented unwanted page-table resizing.
- Fixed startup-window layout and no-network indicator issues on Big Sur.
