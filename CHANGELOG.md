# Changelog

All notable changes to Storybook Packager are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

User-facing release notes for Sparkle auto-update live in
`StorybookPackager/updates/` and are mirrored here at release time.

## [Unreleased]

## [1.9.12] - 2026-08-27

### Fixed
- Long project names in the welcome window's recent projects list are shortened with an ellipsis instead of running out of their row and off to the edge of the window.
- The welcome window opens properly again when a recent project has been renamed or moved. The list of recent projects could name the same project twice — an entry made before a rename and one made after it both point at the file as it now stands — and the welcome window refused to build its list from a repeat, leaving the window on screen small and empty with nothing in it. Repeats are now shown once. If you have been clearing the recent projects list to get the welcome window back, you no longer need to.
- The welcome window sits where it used to again. Version 1.9.11 tried to fix a report of it opening as a small empty box by setting its size and position itself; that was the wrong explanation — the window had not lost its size — and all the change did was move it. It has been taken back out; the real cause is the recent projects list, above.

## [1.9.11] - 2026-08-27

### Fixed
- The welcome window opens properly again instead of as a small empty box with nothing in it. Its two panels never said how wide or tall they were and were being given no room at all, so there was nothing to see; they are now given their proper size, and the window comes back as it should be, with the buttons and the recent projects list in it.
- Opening a project now closes the welcome window behind it, which it had stopped doing.

## [1.9.10] - 2026-08-27

### Added
- Changing a slide's type now asks first when the change would cost you something, and says what: the files that will be dropped, a streaming video's ID, the link to an embedded page, or a quiz's question and answers. Changing between types that keep everything — adding audio to an image slide, switching between kinds of quiz — is unchanged and asks nothing.

### Fixed
- Changing a slide's type no longer leaves it carrying a name that means something else. A slide made into a YouTube, Vimeo or Kaltura slide used to keep its file name as its video ID, and publish it as one; a slide made into a bundle, or out of one, kept a frame list that did not belong to it.
- Replacing the image on a bundle slide that had not been given one before no longer loses it. The picture appeared in the editor as though it had gone in, and was then dropped the next time the presentation was saved.
- Deleting a slide no longer removes another slide's picture or narration. A slide that had never been given a file of its own shared a set of file names with every other such slide, so deleting one took the others' work with it.
- A slide no longer takes over what the slide before it left behind. A slide keeps its own name whether or not its files are there — a picture can be missing because it is being replaced, or was removed on purpose — but the save now clears the name it is moving onto, so nothing that belonged to the previous occupant of that position is inherited.
- Setting a picture, narration, or video on a slide no longer takes a name another slide is already using, even when that slide has no file under it yet.
- Dropping a video onto a slide that is set to play narration but has none no longer asks whether to keep narration that isn't there — and no longer throws the dropped file away when you take the default answer. A brand-new presentation is nothing but such slides, so every video dropped on one was being swallowed.
- The question asked when an imported file really would replace something now names the slide's audio or video properly, instead of offering to keep a file called ".mp3".
- Deleting the first section of a presentation that has more than one no longer quits the app and loses everything unsaved.
- Undoing or redoing a slide deletion no longer quits the app. It was restoring a row number from an outline of a different length; deleting the first slide, or the last, could do it on its own.
- Dropping a batch of files onto a presentation that has been reordered but not yet saved no longer costs a slide its picture or narration. Each imported file is now written straight to the slide it is for, under that slide's own name — the number in a file name says which slide the file is for, never what that slide's files are called. Captions in the same drop follow their media onto the same slide instead of being filed by number and swept.
- Deleting an HTML slide reclaims its content, and undoing the delete brings it back. Anything else kept in the presentation's html folder — shared scripts or styles those slides load — is left alone.
- Setting the audio on an HTML slide no longer costs you the slide's content. The slide's name points at that content, and setting audio used to overwrite it.
- Dropping a video numbered for a quiz slide no longer turns it into a video slide and deletes the quiz. The question, the answers and their images and clips were all lost, without a question being asked and with nothing to undo. The same drop onto a slide showing an embedded page no longer discards the link to that page's content.
- Dropping a batch of files no longer renames a slide that has no room for what was dropped. An image numbered for a slide that plays a streaming video, or shows an embedded page, is reported as not imported instead of quietly renaming that slide and being swept later.
- A file a page cannot hold — a PDF or a stray document numbered like a slide — is now reported rather than silently retitling a slide and importing nothing.
- Bulk import no longer renames a one-section presentation's section to "Untitled".
- A presentation whose asset name prefix contains a hyphen no longer quits the app when files are dropped on it.
- An HTML slide's narration is no longer deleted every time the presentation is saved. It is stored differently from other slides' audio, and the save's tidy-up did not recognise it as belonging to anything.
- A presentation authored with a different asset name prefix keeps it. Opening one whose slides were named "sb01" on a machine set to "page" renamed every file in it on the very next save.
- Deleting a slide that holds an HTML widget now reclaims the widget's folder, which used to stay in the presentation permanently.
- Selecting a video slide in a presentation that has never been saved no longer quits the app.
- Bundle slides no longer show a stray image that belongs to no slide.
- A save that cannot prepare the presentation now reports the failure instead of finishing quietly, which used to leave a package that reopened empty.

## [1.9.9] - 2026-08-27

### Fixed
- A slide added to a saved presentation no longer takes over its neighbour's files. Insert a slide between two others, set just its audio, and you used to get the next slide's picture appearing on it — while the next slide's narration was quietly overwritten with the file you had just chosen. A slide's picture, narration and video are now its own from the moment it is given one: setting one of them never reads, replaces, or claims another slide's file, and a slide with only half of what it takes stays half-filled until you fill it in, marked in the page list the way it always was.
- A slide that has no picture no longer inherits one when the presentation is saved. Delete the first slide of a deck and save, and the slide that moved up into second place used to come back wearing the picture — or the captions — left behind by the slide that had been there. That file is now cleared as the save renumbers the slides. A slide whose picture is simply missing keeps its name and its place in the numbering, so the picture has somewhere to come back to.
- A new presentation set to start with several pages no longer saves a copy of the first slide's image onto every other slide. Every page of a new presentation was in fact the same page, all named for slide one, so a three-page presentation with a picture on slide one wrote out three copies of it.
- Reordering a slide and saving now leaves a correct presentation on disk the first time. The presentation file was written before the slide's picture and narration had been renumbered, so it named the files each slide held at the previous save — the deck displayed correctly in Storybook Packager but the player read it as it was written. Saving a second time repaired it; that is no longer needed.
- Setting a slide's picture, audio, or video now clears the working copy the packager keeps beside it. Left behind, that copy still held the file you had just replaced, and the next time the slide moved in the page list the old file came back.
- Opening an empty bundle slide no longer claims a name that belongs to the slide beside it.
- Narration on an HTML slide can be removed again. The button read "Remove Audio" and then opened a file picker, so the audio could never be taken off; and narration set on an HTML slide by an earlier version is picked up on opening rather than being cleared away by the next save.
- The narration on an HTML slide, and the audio and images on a quiz, are no longer written over or deleted when the slides around them are renumbered. They are stored differently from other slides' media, and the renumbering did not know they were there.
- A quiz that isn't multiple-choice keeps its question image and audio, which the save used to delete.

## [1.9.8] - 2026-08-27

### Added
- **File ▸ Convert Slide Images…** changes the format all of a presentation's slide images are stored in. Pick the format, and Storybook Packager says how many images it will convert and which — if any — it cannot bring with it, before anything changes.
- A batch of slide images in a different format can now change the presentation's format on its way in. Re-export your deck as JPEG, drop the whole thing on the page list, and you are asked once whether to change the presentation to JPEG — then your images go in and the slides your batch didn't cover are converted, so nothing is left behind.
- **Set Image** on a single slide does the same. Choose a file in any slide image format; if it isn't the presentation's, you are asked whether to change the whole presentation to it before the image goes in.
- Converting to or from SVG isn't something the packager can do — a drawing and a picture aren't interchangeable — so any slide whose image can't come along is named before you answer, and left marked as missing an image afterwards. Re-export those slides from whatever produced them.
- If an image turns out not to be convertible once the work starts, the change stops and asks. Cancel leaves the presentation exactly as it was, and whatever you were importing or setting doesn't go in either.
- A drop mixing two image formats settles nothing, so those images are left out and the import report says which and why.

### Changed
- **File ▸ Convert Slide Images…** is unavailable while a presentation is being saved. Saving writes the image files in the background behind a progress sheet that covers the presentation window but not the menu bar, so the command could be chosen mid-save and rewrite the very files being written out.
- When a conversion would leave slides without an image, the button that goes ahead with it no longer answers the Return key, and is marked as the destructive choice. Escape still cancels.
- **Page Image Type** in Properties is now shown rather than set; use **File ▸ Convert Slide Images…** to change it. Changing it in Properties used to change the setting and nothing else, which left every image in the presentation unreachable and the next save deleted the lot without a word.

### Fixed
- SVG slides exported without a size on them — what a "responsive" export produces — now display correctly. Fitting the drawing to the preview was reaching into the drawing itself and removing the height of the first shape in it, which showed as a blank slide when that shape was the background and a misdrawn one otherwise.
- SVG slides are centred in the preview rather than pushed to the left edge, and a tall drawing is shown whole instead of being cut off at the bottom. An SVG that specifies its own alignment is now left to it. Automatic slide titles are read from this same preview, so a title read off an SVG slide may differ slightly from before.
- Dropping images that aren't in the presentation's format used to refuse the whole drop silently — no cursor, no alert, nothing to explain it. The drop is now accepted and answered.
- Copying slides between two presentations set to different image formats used to write the images across unchanged, under a file name claiming a format they weren't, so they no longer displayed anywhere. PNG and JPEG images are now converted on the way over; an image can't be converted to or from SVG, so those slides arrive without their image and are marked as missing one.

## [1.9.7] - 2026-08-25

### Changed
- Frame timecodes in the list of a bundle slide are now shown in full — 05:47.00 rather than 05:47 — so the column reads straight down. A frame past the hour counts on in minutes, 61:40.00, rather than starting over. Frames are still stored the way they always were, so presentations and the player are unaffected, and you can still type a timecode in any of the shorter forms.
- The frames list has room for three-digit frame numbers, and no longer carries an empty column header above the first row.

## [1.9.6] - 2026-08-25

### Changed
- Release notes pages now list the build's commit and the download's SHA-256, so a copy of Storybook Packager can be traced back to the exact source it was built from and a download can be checked by hand.
- Bundle slides are laid out like every other slide now. The slide preview is full size instead of being cut down to two thirds of the width, and the list of frames has moved out from beside the slide to sit beside the Notes and Widgets panes, under its own "Frames" heading. The overall height of the editor is unchanged.
- The frame buttons now run down the right-hand side of the frames list rather than along the bottom, where four of them no longer fitted the width and the first one was being clipped. Standing them up leaves room for more of them later.

### Fixed
- Updates now come from this repository rather than a separate web server, and the update feed's history has been repaired. Every past version's entry pointed at a single download that each release overwrote, so only the newest entry was ever valid; each one now points at the disk image kept with its own release. Nothing changes about how updating works from your side.
- Captions on a bundle slide are no longer drawn off-centre. They were being centred across the whole editor area, including the frames list beside the slide, rather than over the slide itself.

## [1.9.5] - 2026-08-25

### Added
- A video can now be dropped straight onto the slide you are editing. Drop a single MP4 anywhere on the preview of a Video, Kaltura, YouTube, or Vimeo slide and it becomes that slide's video — the file name doesn't matter, because the slide it lands on is the one on screen. A slide that was streaming from Kaltura, YouTube, or Vimeo becomes an ordinary video slide playing the presentation's own copy, and the streaming ID it was playing is not kept. Dropping onto the import box at the page list works exactly as before, file names and all.
- Replacing a video that the slide has captions for now checks whether those captions still fit the new video's length, and offers to clear them if they don't. Captions timed to the video you just replaced would otherwise stay on the slide, describing something that is no longer there.

### Fixed
- Dropping a file onto a slide preview that is drawn by a web view — an SVG slide, the YouTube or Vimeo player, or the SVG preview in Properties — no longer makes that preview go off and display the file you dropped. A preview is a picture of the slide, so a file dropped on one now either goes to the slide, when the slide is one that takes it, or is ignored.

### Changed
- The copyright notice on the welcome window and in the About box now reads "Copyright © 2018-2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved." — the organization's current name, and a year range rather than a single year that had fallen behind. The welcome window shortens the name to "Universities of Wisconsin OPLR", which is all the one line there has room for. Cutting a release now rolls that range to the year of the release, in the app and in the README, so it can't go stale again.
- The four buttons under the Frames list of a bundle slide — add, delete, set time, and replace image — are now ordinary bordered buttons, matching the Title Case and OCR buttons above the slide. They were flat icons with no button around them, which made them hard to pick out as things you could press and hard to hit.

## [1.9.4] - 2026-08-24

### Changed
- The Frames list of a bundle slide has been tidied up. The set-time and replace-image buttons that sat on every row have moved down beside + and −, where they act on the frame you have selected. That gives each row its full width for the timecode, so times no longer read as "00:10…" now that they can carry hundredths.
- Pin Controls has moved out of the frames panel to the right-hand end of the Sources row, where there is room for it. It appears for bundle slides, which are the ones with controls to pin.

## [1.9.3] - 2026-08-24

### Changed
- Frame timecodes are no longer rounded to the nearest second. A frame can be pinned to a hundredth — 00:04.75 — by typing it, or with the set-time button, which now takes the exact moment the narration is at rather than the second it is nearest. Whole seconds still read as plain 00:04, so existing presentations are unchanged, and the player already understands both forms.
- Adding or dropping images into a gap too tight for whole seconds now shares the gap out between them rather than refusing. Only a gap too small to separate them at all is turned away.
- The first frame of a bundle slide can now be deleted, including when it is the only one. Whatever image follows takes over the start of the slide, since something has to be on screen when the narration begins — so the new first frame moves to 00:00 and keeps its own image. Deleting every frame leaves the slide with narration and no images; reopening the presentation gives it back a single empty frame at 00:00, ready for you to drop an image on.
- Images can now be dropped above the first frame of a bundle slide. They take over the start of the slide, and the frame that was first moves to the second after them.
- Adding frames with the + button now puts them where the playhead is in the running order, rather than on the end of the list.
- Deleting more than one frame at once now asks first. Frame deletion can't be undone and the images leave the presentation with it, so selecting the whole list and pressing delete is worth a moment's confirmation. Deleting a single frame is unchanged.

### Fixed
- Timecodes past the hour wrapped instead of counting on: a frame set at 61:40 was recorded as 01:40, which reads as earlier than the frame before it and put the running order out. Times over an hour are now written as 01:01:40, and typing one in is read correctly — an hour previously counted as a single minute.
- Replacing a frame's image could silently come undone. If the presentation had been imported in bulk, moving the slide in the outline afterwards brought the old image back as though the replacement never happened.
- Frames added with the + button while the playhead sat before the last frame were appended to the end of the list anyway, leaving the frames out of order. An out-of-order list is what the player and the preview both read, so the wrong image showed from that point on.
- On a bundle slide created in this session, every image added with the + button was written under a name the editor never looks for — the slide named itself one way and the button named the images another. Replacing an image had the same fault.
- A frame's timecode can no longer be set to one that puts it out of order. Typing a time checked only that no other frame already held it, and the set-to-playhead button checked nothing at all, so parking the playhead before the previous frame and pressing it was enough to scramble the running order. Both now say what's wrong and leave the frame as it was.
- The timecode of a frame could come up locked, and its set-time button missing, on a frame that was not the first — the rows shifting up after a delete could hand a row the first frame's locked appearance.

## [1.9.2] - 2026-08-24

### Fixed
- Selecting several frames in a bundle slide no longer drags the narration's playhead along with it. Each shift-click was moving playback to the frame you had just reached, which fought the selection you were building. Clicking a single frame still takes you to it, and the preview still follows the frame you touched last.
- A multi-frame selection is no longer thrown away by the narration. Seeking, pausing, or letting playback cross into the next frame all re-selected the current frame on your behalf, wiping out a selection you had just made to delete. The frame list still follows along whenever you have one frame or none selected.

## [1.9.1] - 2026-08-24

### Added
- You can now select more than one frame in a bundle slide's Frames list and delete them in one go. Frame 1 is left alone, since every bundle starts on it — selecting it along with others simply keeps it.

### Fixed
- Scrubbing a bundle's narration showed the first image instead of the one belonging to where you landed. Dragging the playhead — and clicking a frame in the list, which moves the playhead to it — always snapped the picture back to frame 1. Playing straight through was unaffected, which is why this went unnoticed. Introduced in 1.8.2 by the fix for the crash on bundles whose first image is timed later than 00:00; that crash stays fixed.
- Editing a frame's timecode while several frames were selected wrote the new time onto the wrong frame.

## [1.9.0] - 2026-08-24

### Added
- You can now drag a set of images straight onto the Frames list of a bundle slide. They're added as new frames at the spot you drop them, in filename order, each given its own timecode. Dropping between two frames that are too close together to hold them says so and adds nothing.

## [1.8.2] - 2026-08-19

### Added
- A presentation's transcript can now be an HTML file as well as a PDF. The Transcript slot in the Files dialog takes either one — choose a `.pdf` or an `.html`, or drop one in — and holds one at a time: setting a web transcript replaces a PDF and the other way round, so the presentation never carries two. The button shows which form is in place, and says so on hover. A presentation named "index" can't take a web transcript — that transcript would have to be called `index.html`, the name the presentation itself uses — so the app says so instead of replacing the presentation with it.

### Fixed
- Reloading a captioned video slide could quit the app. The slide's player was replaced while the caption timer was still attached to the old one, which AVFoundation treats as a hard error. Captions released 1.8.1; this reaches it through Save & Reload on a video slide that has captions.
- Pressing Play on a bundle that has narration but no images no longer quits the app.
- Replacing the audio, video, or archive download in the Files dialog with a file that can't be read no longer takes the existing one with it — the same protection the transcript slot got.
- A download set or removed in the Files dialog now marks the presentation as edited, so closing it without saving asks rather than discarding the change silently.
- Playing a bundle whose first image is timed later than 00:00 quit the app on the spot. Typing a timecode on the first frame, or adding frames while the narration plays, produces exactly that bundle.
- Setting a slide's image, audio, or video now clears the outline's warning mark and lights its caption mark straight away, instead of leaving them as they were until the presentation was closed and reopened.
- Replacing a transcript with a file that can't be read no longer takes the old transcript with it. The file is read first, and the presentation is left as it was if it can't be.
- Saving a presentation under its existing name in a different folder no longer renames every download — transcript, audio, video, bundle — to a name the player doesn't look for. Cancelling Save As no longer does it either.
- Setting or removing a file in the Files dialog no longer risks writing a half-old, half-new package if the dialog is used again while the save is still running.
- Hovering a section header in the slide list no longer shows a warning left over from a slide.
- Opening a presentation that carries stray files at its top level no longer files two of them under the same name, leaving one that nothing ever reads.
- Captions no longer sit under the video's own controls, and a long caption wraps instead of being cut off.

## [1.8.1] - 2026-08-19

### Added
- Captions can now be set on a slide directly, without dropping a file in: a **Set Captions** button sits with the other source buttons on the slide types that can carry them — an image with narration, a bundle, and a video. It takes a `.vtt` or an `.srt` and converts on the way in, exactly as a dropped file is converted.
- The source buttons now say what they will do. When a slide already has an image, audio, video, or captions, the button that set it reads **Remove Image**, **Remove Audio**, **Remove Video**, or **Remove Captions** instead, and asks before removing anything. Removing takes the file out of the presentation on the next save; the file it was imported from is left alone.
- Every slide in the outline now carries a caption mark beside its type — "VIDEO  CC". It is lit when the captions are in place, dimmed when they are missing, and a dash on slide types that can't take captions at all, so a whole presentation can be checked for missing captions at a glance rather than slide by slide.
- Slides in the outline now carry a warning mark when they are in a state nothing else complains about but that is plainly wrong — a slide set to play narration with no audio, captions left beside audio or video that was removed, a bundle with no images, a Kaltura, YouTube, or Vimeo slide with no video ID. Hovering the mark says what is wrong, a line per thing. Slide types that hold no media of that kind — quizzes, HTML slides, section headers — are never marked, so a mark always means something.
- Captions now play in the editor. On a video, an image with narration, or a bundle, the cue for the current moment is drawn over the slide as it plays, and follows the scrubber when you drag it — so whether the captions line up with the narration can be checked in the app instead of in the finished presentation.

### Fixed
- The dialog that asks before replacing a slide's media asked backwards. It listed one checkbox per slide, checked to mean "use the video" and cleared to mean "use the audio" — read as a list of replacements to turn down, clearing a box chose the very replacement it was meant to refuse. Each slide is now a short menu of what to do with it, worded as what it does: "Keep sb04.mp4" or "Replace with narration04.mp3". Every slide opens on keeping what it already has, so importing without touching the list replaces nothing, and a dropped file you don't choose is not imported.
- Importing media onto a Kaltura, YouTube, or Vimeo slide now asks first, the way it already does for a slide authored as a video or as an image with narration. A streaming slide holds only the ID of a video hosted elsewhere, so dropping an `.mp3` or `.mp4` numbered for that slide wrote the ID away with no warning and no way to get it back from the presentation — including a dropped video, which on an ordinary video slide is just a routine replacement.
- A slide that has both an `.mp3` and an `.mp4` dropped on it can now be left alone as well. Before, that slide had to become one or the other.
- Dropping a folder of media over a run of slides no longer means setting every slide by hand: **Replace All** and **Keep All** sit above the list. They move only the slides that offer a single replacement — a slide carrying both an `.mp3` and an `.mp4` is a decision rather than a default, so it is left where it stands — and they don't appear at all when there is nothing for them to do.
- Dropping a caption file on a Kaltura, YouTube, or Vimeo slide no longer says the page has no audio or video to attach it to — said of a page whose whole content is a video, which sent people off to import an `.mp4` that would have destroyed the slide had they found one. Those slides now get their own explanation: the video is hosted elsewhere, so its captions come from the site hosting it. Captions in a presentation attach to audio or video the presentation itself holds, and a streaming slide holds only a video ID.
- Reports about files that weren't imported now read correctly when only one file was skipped, instead of describing a single file as "these file names".

## [1.8.0] - 2026-08-19

### Added
- Caption files can now be dragged in like any other asset. Drop a `.vtt` or `.srt` onto the import box and it is filed with the page whose number its file name ends in — next to that page's narration audio, or next to its video for a video page. Captions attach to a page that already has audio or video, or to one being created by the audio or video file dropped alongside them in the same batch. Like every other imported asset, captions are renamed to follow their page as pages are reordered.
- `.srt` files are converted to the `.vtt` format the player reads as they come in. The conversion fixes what a browser rejects in a SubRip file: comma decimal separators in the timestamps, the missing `WEBVTT` signature, cue numbers, Windows line endings, and non-UTF-8 text (accents from a Windows-encoded file are preserved rather than lost). A `.vtt` file that isn't valid — most often a SubRip file with a `WEBVTT` line pasted on top, which a browser accepts as a caption track and then shows nothing from — is repaired the same way rather than taken at its word. Caption text is otherwise left as written, apart from player-specific markup a browser would show as literal text: `{\an8}` positioning and `<font>` tags are removed, while bold, italic, and underline are kept.
- Importing media that would replace a slide's existing media now asks first. A slide is either a video or an image with narration, never both, so dropping narration onto a slide authored as a video used to replace that video silently — easy to do by grabbing a folder of audio and forgetting that one or two slides were built as video. The import now stops and lists every slide caught in the middle, with a checkbox per slide: checked keeps or uses the video, unchecked keeps or uses the audio. It asks in both directions, and for slides where the drop itself carries both an `.mp3` and an `.mp4` for the same page number. Each slide starts out set to whatever the presentation already holds, so accepting the dialog as it opens changes nothing that was already authored; Cancel imports nothing at all. Slides that lose nothing — narration onto a slide that has no audio yet, or a replacement of the same kind — are imported without asking.
- Files that couldn't be imported are now listed in a single message at the end of the import, each with its reason: no page number in the file name, a caption with no audio or video to attach to, or a caption file that couldn't be read.

### Fixed
- Dropping a file whose name ends in no page number — `captions.srt`, `lecture.mp3`, `slide.jpg` — no longer quits the app on the spot. Reading the page number out of such a name crashed outright; the file is now listed as not imported, with a note to number it after the page it belongs to.

## [1.7.0] - 2026-08-19

### Changed
- JPG and JPEG slides are now treated as one and the same. The Page Image Type setting no longer offers JPEG as a separate choice (in a presentation's Properties or in Preferences ▸ Default page format) — a presentation set to JPG accepts slides saved with either spelling, whether you drag them in, drop them on the import box, or pick them with the Browse button, and stores them as `.jpg`. Previously the two were separate formats: a `.jpeg` slide dropped into a JPG presentation was rejected by the import box, and one attached any other way was invisible in the editor and discarded on the next save. Opening a presentation that was set to JPEG converts it once — the setting becomes JPG and the slide files in `assets/pages/` are renamed to match, then the presentation is saved. The Splash Image Type setting still offers both, because it has to match the file name on the centralized asset server.
- Updated the built-in components the app relies on. The auto-update mechanism (Sparkle) moves from 2.9.3 to 2.9.6, which brings three rounds of security hardening to the part that installs a downloaded update — including refusing an installer whose signature fails to validate. The network-availability check (Reachability) moves to its current release, replacing a development snapshot from 2020 that the app had been building against.

### Fixed
- Presentation properties no longer mangle punctuation a little more on every save. A comma, ampersand, apostrophe, quote mark, or any of ``! $ % + < = > @ [ ] ` { }`` in the **Program**, **Course**, or **Author name** field came back as its character code (a comma turned into `&#44;`), and each subsequent save encoded that result again — `&#38;#44;`, then `&#38;#38;#44;` — until the field was unreadable. The text is now read back exactly as typed, and opening an affected presentation repairs the field however many saves it has been through. Anything you typed that only looks like a character code is left alone. Page titles, section titles, and the Title, Subtitle, Length, Author profile, and General info fields were never affected.
- Text you typed that merely looks like a character code is no longer silently rewritten when a presentation is saved. A page title, section title, widget segment name, or copyable content name containing something like `&amp;` had that turned into a plain `&` — every save, so `&amp;amp;` became `&amp;` became `&`. Those fields are now stored exactly as typed.
- Deleting a page with narration audio (an image + audio page or a bundle page) now also removes its caption (`.vtt`) file. The caption was left behind in the project's audio folder, where it would linger unused and could later be picked up by an unrelated page that happened to be renumbered into the same slot. Deleting a video page already removed its captions correctly.

## [1.6.0] - 2026-07-22

### Added
- Undo and redo (⌘Z / ⇧⌘Z) now cover structural changes to the page list: adding a page or section, duplicating, pasting, deleting, and reordering by drag. Undoing a delete brings the page back together with its media (image, audio, video, captions), and undoing a duplicate or paste removes the copies it made. Edits to the contents of a page — title text, quiz answers, notes, colors — are not covered by this and continue to behave as before. Because saving renames every asset file to match its page position, the undo history ends at each save (and after a bulk file import); undo covers the changes made since.
- Right-click a page or section in the page list for a menu with Duplicate, Copy, and Paste. Right-clicking a row that isn't selected selects it first, so the command acts on the row under the pointer.
- A Duplicate button in the page-list toolbar, next to Add Page / Add Section, duplicating the selection in place (the same as Edit ▸ Duplicate / ⌘D).

### Changed
- The Add Page and Add Section buttons in the page-list toolbar are now their natural width instead of being stretched, and the empty gap before the Delete button is gone.

### Fixed
- The Properties dialog no longer freezes the whole app while it loads a splash-image preview from the centralized asset server. The preview was downloaded synchronously on the main thread with no timeout, so a slow or unreachable server would beach-ball the app — and, on a bad connection, could stop it from becoming usable at all. The preview now loads in the background, a spinner shows while it works, and a Cancel button appears after 30 seconds so a hung server can't leave the dialog stuck. When the requested splash can't be reached the centralized default splash is shown instead.

## [1.5.4] - 2026-07-20

### Fixed
- Importing a large batch of slide images (roughly 60 or more) no longer hangs the app while titles are guessed. Every image's text recognition was started at once, exhausting the system's worker threads; recognition now runs at most three images at a time, so big imports finish in waves instead of wedging the whole app.

## [1.5.3] - 2026-07-10

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
