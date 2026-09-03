# changelog.py

Adds an entry to both changelogs at once.

| File | Who reads it | What goes in it |
| --- | --- | --- |
| `CHANGELOG.md` | instructors, course designers | one plain sentence per entry — becomes the Sparkle update notes |
| `CHANGELOG-INTERNAL.md` | us | the cause, the files, the gotchas — never published |

## Use

```sh
tools/changelog/changelog.py fixed "Fixed a crash when X while Y." -i "What actually went wrong."
tools/changelog/changelog.py added "Slides can be named from their images." -i "..." --files PageViewController.swift
tools/changelog/changelog.py internal "Split the save path in two."   # nothing user-visible to say
tools/changelog/changelog.py show                                     # both Unreleased sections
tools/changelog/changelog.py lint                                     # check the public entries
```

Sections: `added`, `changed`, `deprecated`, `removed`, `fixed`, `security`, plus
`internal` for work with no user-visible change.

| Option | Effect |
| --- | --- |
| `-i`, `--internal` | the technical note for the internal log |
| `--files a.swift b.swift` | record what was touched, in the internal log |
| `--internal-only` | keep it out of the public log |
| `--no-internal` | public entry only |
| `--strict` | refuse an entry that fails the style check |

## The style check

`lint`, and every `add`, checks the public sentence against the rules in the "Writing an
entry" section at the top of `CHANGELOG.md`: one sentence, ends in a full stop, no file
names or symbols, and — for a fix — a clause saying *when* it happened. "Fixed a crash
when importing files" is flagged, because it reads as though every import crashes.

Warnings only, so it never blocks you. `--strict` turns them into a refusal.

## Releases

`build-release.sh` rolls both files to the new version together. Only `CHANGELOG.md`
reaches the release notes and the GitHub release; the internal log is committed and goes
no further.
