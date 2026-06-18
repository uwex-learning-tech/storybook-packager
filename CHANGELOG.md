# Changelog

All notable changes to Storybook Packager are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

User-facing release notes for Sparkle auto-update live in
`StorybookPackager/updates/` and are mirrored here at release time.

## [Unreleased]

### Added
- Auto-calculate the presentation **Length** from page media: a button next to the Length field in Properties opens a dialog where you set a fallback duration (default 30s) for slides that can't be measured, then estimates the total as whole minutes. Narrated/audio and local-video pages use their real durations; Vimeo (oEmbed), Kaltura (HLS), and YouTube (watch-page lookup) streaming pages are measured over the network; image-only, quiz, and HTML pages use the fallback.
- Copy sections and pages between open presentations, by drag-and-drop or Edit ▸ Copy/Paste (⌘C/⌘V). Selecting a section copies it together with all of its pages. Pasted pages are fully independent copies — they bring their own copies of every referenced asset (page images, narration and bundle audio, video, captions, quiz images/audio, and HTML widget folders) under non-colliding names, and the source presentation is never changed. Copy/paste also works within a single presentation to duplicate pages in place.

### Fixed
- Caption (`.vtt`) files now stay paired with their page when pages are renumbered on save, instead of being dropped.

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
