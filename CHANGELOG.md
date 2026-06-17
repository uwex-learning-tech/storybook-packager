# Changelog

All notable changes to Storybook Packager are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

User-facing release notes for Sparkle auto-update live in
`StorybookPackager/updates/` and are mirrored here at release time.

## [Unreleased]

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
