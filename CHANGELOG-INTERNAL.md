# Internal changelog

Engineering notes that sit alongside `CHANGELOG.md`. This file is never published: it
is where the cause, the files touched, and anything worth knowing when a change comes
back to bite us belongs, so the public entries can stay one plain sentence.

Entries are added with `tools/changelog/changelog.py`, and rolled to a version by
`build-release.sh` at the same time as the public log.

## [Unreleased]

## [1.9.15] - 2026-09-03

### Fixed
- Fixed a crash that could happen when importing files while a slide's video ID was still being typed.
  - `videoIdChange` resolved its page with `getXmlObjPages()[currentPageIndex.first!]`. A bulk import posts `reloadPageOutline`; the outline's `reloadData` calls `deselectAll` first, which empties `currentPageIndex` and hides the editor — and hiding it is what makes the field resign and fire its action. Empty selection, force unwrap, EXC_BREAKPOINT.
  - Added bounds-checked `Document.currentXmlPage()` and moved ~51 call sites of the same pattern onto it, across the page editor and every quiz/bundle/widget controller.
  - `currentXmlPage()` deliberately does not call `getXmlObjPages()`: that accessor mutates the model as a side effect (it strips the lone section header out of the stored array), and this is called on every field commit.
  - Files: Document.swift, PageViewController.swift, BundleViewController.swift, WidgetsViewController.swift, HtmlViewController.swift, QuizViewController.swift, MultipleChoiceViewController.swift, MultipleAnswerViewController.swift, ShortAnswerViewController.swift, FillInTheBlankViewController.swift
- Fixed edits being lost when slides are imported, added, deleted, duplicated, pasted, reordered, or undone while text was still being typed.
  - The first attempt at the crash fix pinned the video ID field to its page with a weak reference. That was wrong: `refreshPageCollectionWithNew` rebuilds the model through `copy()`, so every `Page` identity is replaced and the weak reference is already nil by commit time — the edit was silently dropped rather than kept.
  - The actual fix is to end editing *before* the rebuild, which is what `Document.save` has always done. `makeFirstResponder(nil)` now runs at the top of `importFiles`, the outline's add/delete/paste/duplicate actions, and `performTransition` (undo/redo). The weak-reference pin stays as a backstop.
  - Files: ProjectViewController.swift, PageOutlineViewController.swift, Document.swift
- Fixed a case where an HTML widget's saved content could be erased while it was being edited.
  - `loadWidget` blanked `widgetTxtVw` and then re-selected row 0. Re-selecting the already-selected row posts no `tableViewSelectionDidChange`, so the view stayed empty *and* first responder, and committed that emptiness over the segment's saved content. Reachable with no import at all — an async OCR completion re-posts `pageSelected` for the same page, which reloads the panel.
  - Files: WidgetsViewController.swift
- Fixed a widget segment's name, or a quiz answer's text and feedback, landing on the wrong row when the selection moved mid-edit.
  - These derived the row from `selectedRow` rather than from the sender, so any selection move between typing and commit misfiled the text. `BundleViewController.frameTimeChange` already did this correctly with `row(for:)` and carries a comment explaining why; the others now match it.
  - Files: WidgetsViewController.swift, MultipleChoiceViewController.swift, MultipleAnswerViewController.swift
- Fixed a crash in the welcome window when pressing Return with no project selected, and one in Properties when typing a program or course number before the server answered.
  - `urls[selectedRow]` with no bounds check, reachable because `RecentsTableView.keyDown` fires the double-click action on Return and `selectedRow` is -1 with nothing selected. Separately, `programChange`/`courseChange` force-unwrapped `manifest`, which only exists once the media.uwex.edu fetch returns; the neighbouring year and author handlers already guarded it.
  - Also guarded `row(for:)` returning -1 on a detached cell in the two quiz `setCorrect` actions.
  - Files: RecentsTableViewController.swift, PropertiesDialogController.swift, MultipleChoiceViewController.swift, MultipleAnswerViewController.swift

### Changed
- Not in the public log: no user-visible change.
  - Added `tools/changelog/changelog.py` and this file. Entries go into both logs in one command; the script also lints the public `[Unreleased]` entries against the "Writing an entry" rules at the top of `CHANGELOG.md`.
  - Known gap, deliberately left: the quiz editors still write `currentPage.quiz.choices = choices!` on every keystroke, stamping a whole cached array back over the answers. Not reachable as corruption now that the row derivation and the pre-rebuild flush are in, but it is fragile and wants its own pass.
  - Open question from review, needs a runtime check rather than more reading: whether AppKit runs `selectionIndexesForProposedSelection` for *programmatic* selection. If it does not, right-clicking a different outline row while a text field holds focus could commit page A's notes onto page B.
  - Files: tools/changelog/changelog.py, tools/changelog/README.md, CHANGELOG-INTERNAL.md
