#!/usr/bin/env python3
"""Add entries to the changelogs.

There are two logs and they are written together:

  CHANGELOG.md           what users read — one plain sentence per entry, no mechanism.
                         This is what build-release.sh turns into the Sparkle notes.
  CHANGELOG-INTERNAL.md  what we read — the same change with the cause, the files, and
                         anything worth knowing when it comes back. Never published.

Usage:

  tools/changelog/changelog.py fixed "Fixed a crash when X while Y." -i "Cause and detail."
  tools/changelog/changelog.py added "Slides can now be named from their images." -i "..." --files A.swift
  tools/changelog/changelog.py internal "Split the save path in two."          # no user-visible change
  tools/changelog/changelog.py show                                            # both Unreleased sections
  tools/changelog/changelog.py lint                                            # check the public entries

Sections: added, changed, deprecated, removed, fixed, security.
Add --internal-only to keep an entry out of the public log entirely, or --no-internal
when there is genuinely nothing to say beyond the public sentence.
"""

import argparse
import os
import re
import subprocess
import sys
from datetime import date

def repo_root():
    """Walk up from this file until CHANGELOG.md turns up, so the script can be moved."""
    path = os.path.dirname(os.path.abspath(__file__))
    while True:
        if os.path.exists(os.path.join(path, "CHANGELOG.md")):
            return path
        parent = os.path.dirname(path)
        if parent == path:
            raise SystemExit("Could not find CHANGELOG.md above %s" % os.path.abspath(__file__))
        path = parent


ROOT = repo_root()
PUBLIC = os.path.join(ROOT, "CHANGELOG.md")
INTERNAL = os.path.join(ROOT, "CHANGELOG-INTERNAL.md")

# Keep a Changelog's order. A new section is inserted so the file keeps it.
SECTIONS = ["Added", "Changed", "Deprecated", "Removed", "Fixed", "Security"]

INTERNAL_HEADER = """# Internal changelog

Engineering notes that sit alongside `CHANGELOG.md`. This file is never published: it
is where the cause, the files touched, and anything worth knowing when a change comes
back to bite us belongs, so the public entries can stay one plain sentence.

Entries are added with `tools/changelog/changelog.py`, and rolled to a version by
`build-release.sh` at the same time as the public log.

## [Unreleased]
"""


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def branch():
    try:
        name = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        ).stdout.strip()
        return name or "?"
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "?"


def unreleased_bounds(text):
    """The slice of `text` between '## [Unreleased]' and the next '## ' heading."""
    match = re.search(r"^## \[Unreleased\][^\n]*\n", text, re.M)
    if not match:
        return None
    start = match.end()
    nxt = re.search(r"^## ", text[start:], re.M)
    end = start + nxt.start() if nxt else len(text)
    return start, end


def insert_entry(text, section, lines):
    """Put `lines` at the end of `section` inside the Unreleased block."""
    bounds = unreleased_bounds(text)
    if bounds is None:
        raise SystemExit("No '## [Unreleased]' heading found — cannot add an entry.")

    start, end = bounds
    block = text[start:end]
    entry = "\n".join(lines) + "\n"

    heading = re.search(r"^### %s\s*$" % re.escape(section), block, re.M)
    if heading:
        # Append after the last line of this section's body.
        after = block[heading.end():]
        nxt = re.search(r"^### ", after, re.M)
        body_end = heading.end() + (nxt.start() if nxt else len(after))
        body = block[heading.end():body_end].rstrip("\n")
        new_block = block[:heading.end()] + body + "\n" + entry + "\n" + block[body_end:].lstrip("\n")
    else:
        # New section, placed in Keep a Changelog order among the ones already there.
        present = [(m.start(), m.group(1)) for m in re.finditer(r"^### (\w+)\s*$", block, re.M)]
        rank = SECTIONS.index(section) if section in SECTIONS else len(SECTIONS)
        at = len(block.rstrip("\n"))
        for pos, name in present:
            other = SECTIONS.index(name) if name in SECTIONS else len(SECTIONS)
            if other > rank:
                at = pos
                break
        head = block[:at].rstrip("\n")
        tail = block[at:].lstrip("\n")
        piece = "### %s\n%s" % (section, entry)
        new_block = (head + "\n\n" if head else "") + piece + ("\n" + tail if tail else "\n")

    # Keep the blank line the file uses between a version heading and its first section.
    if not new_block.startswith("\n"):
        new_block = "\n" + new_block

    return text[:start] + new_block + text[end:]


# ---------------------------------------------------------------------------------------
# Style checks. These mirror the "Writing an entry" section at the top of CHANGELOG.md.
# They warn rather than block, except under --strict.
# ---------------------------------------------------------------------------------------
SENTENCE_END = re.compile(r"[.!?]$")

# Product names that look like code but are what the thing is actually called.
NOT_CODE = {
    "YouTube", "Vimeo", "Kaltura", "Storybook", "Packager", "AppKit", "PowerPoint",
    "macOS", "iCloud", "PDF", "HTML", "SVG", "XML", "ID",
}

# A symbol, a file name, a dotted identifier, or run-together capitals — the shapes that
# mean a sentence is describing the code rather than what someone saw.
CODEY_TOKEN = re.compile(r"\b\w+\.\w+\b|\b(?:[A-Z][a-z0-9]+){2,}\b|\b\w+\(\)")
CODEY_WORD = re.compile(r"`|\bnil\b|\bnull\b|\bforce[- ]unwrap\w*|\brefactor\w*|\bexception\b|\bstack trace\b", re.I)


def reads_technical(text):
    if CODEY_WORD.search(text):
        return True
    for token in CODEY_TOKEN.findall(text):
        bare = token.split(".")[0]
        if token in NOT_CODE or bare in NOT_CODE:
            continue
        if token.lower().endswith((".md", ".app")):
            continue
        return True
    return False


def style_warnings(sentence, section):
    warnings = []
    text = sentence.strip()

    if not text:
        warnings.append("entry is empty")
        return warnings
    if not text[0].isupper():
        warnings.append("start with a capital letter")
    if not SENTENCE_END.search(text):
        warnings.append("end with a full stop")
    # Two sentences: a full stop followed by a space and a capital.
    if re.search(r"[.!?]\s+[A-Z]", text):
        warnings.append("keep it to one sentence — the second belongs in the internal note")
    if len(text) > 220:
        warnings.append("long for one sentence (%d chars) — trim it" % len(text))
    if reads_technical(text):
        warnings.append("reads technical — no file names, symbols, or code in the public log")
    if section == "Fixed" and not re.search(r"\b(when|while|after|if)\b", text):
        warnings.append("say when it happened — without the condition this reads as though it always did")
    if re.search(r"\b(claude|agent|ai)\b", text, re.I):
        warnings.append("no tooling or assistant references in the changelog")
    return warnings


def cmd_add(args):
    section = args.section.capitalize()
    if section == "Internal":
        section, args.internal_only = "Changed", True
        if not args.internal:
            args.internal, args.text = args.text, ""

    public = args.text.strip()
    note = (args.internal or "").strip()

    if not args.internal_only:
        if not public:
            raise SystemExit("Nothing to add: give the sentence users will read, or use --internal-only.")
        warnings = style_warnings(public, section)
        if warnings:
            print("Style:", file=sys.stderr)
            for warning in warnings:
                print("  - %s" % warning, file=sys.stderr)
            print("  (see 'Writing an entry' at the top of CHANGELOG.md)", file=sys.stderr)
            if args.strict:
                raise SystemExit("Refusing to write — rerun without --strict to add it anyway.")

        text = insert_entry(read(PUBLIC), section, ["- " + public])
        write(PUBLIC, text)
        print("CHANGELOG.md          %s: %s" % (section.lower(), public))

    if args.no_internal and not args.internal_only:
        return

    if not os.path.exists(INTERNAL):
        write(INTERNAL, INTERNAL_HEADER)

    lines = ["- " + (public if public else note)]
    if public and note:
        lines.append("  - %s" % note)
    if args.files:
        lines.append("  - Files: %s" % ", ".join(args.files))
    if args.internal_only:
        lines.append("  - Not in the public log: no user-visible change.")
    lines.append("  - %s · %s" % (date.today().isoformat(), branch()))

    write(INTERNAL, insert_entry(read(INTERNAL), section, lines))
    print("CHANGELOG-INTERNAL.md %s: %s" % (section.lower(), public or note))


def cmd_show(_args):
    for path in (PUBLIC, INTERNAL):
        if not os.path.exists(path):
            continue
        bounds = unreleased_bounds(read(path))
        body = read(path)[bounds[0]:bounds[1]].strip() if bounds else ""
        print("── %s ── Unreleased" % os.path.basename(path))
        print(body if body else "  (empty)")
        print()


def cmd_lint(args):
    bounds = unreleased_bounds(read(PUBLIC))
    if bounds is None:
        raise SystemExit("No '## [Unreleased]' heading in CHANGELOG.md.")

    block = read(PUBLIC)[bounds[0]:bounds[1]]
    section, problems, checked = None, 0, 0

    for line in block.splitlines():
        heading = re.match(r"^### (\w+)", line)
        if heading:
            section = heading.group(1)
            continue
        if not line.startswith("- "):
            continue
        checked += 1
        warnings = style_warnings(line[2:], section or "")
        if warnings:
            problems += 1
            print("• %s" % line[2:])
            for warning in warnings:
                print("    - %s" % warning)

    if not checked:
        print("Nothing in [Unreleased] to check.")
        return
    if problems:
        print("\n%d of %d entries could read better." % (problems, checked))
        if args.strict:
            sys.exit(1)
    else:
        print("%d entries, all good." % checked)


def main():
    parser = argparse.ArgumentParser(
        prog="tools/changelog/changelog.py",
        description="Add an entry to the public and internal changelogs.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Usage:", 1)[1] if "Usage:" in __doc__ else None,
    )
    sub = parser.add_subparsers(dest="command")

    add = sub.add_parser("add", help="add an entry (the default)")
    add.add_argument("section", help="added | changed | deprecated | removed | fixed | security | internal")
    add.add_argument("text", nargs="?", default="", help="the sentence users will read")
    add.add_argument("-i", "--internal", default="", help="the technical note for the internal log")
    add.add_argument("--files", nargs="*", default=[], help="files this touched, for the internal log")
    add.add_argument("--internal-only", action="store_true", help="keep it out of the public log")
    add.add_argument("--no-internal", action="store_true", help="public entry only")
    add.add_argument("--strict", action="store_true", help="refuse entries that fail the style check")
    add.set_defaults(func=cmd_add)

    show = sub.add_parser("show", help="print both Unreleased sections")
    show.set_defaults(func=cmd_show)

    lint = sub.add_parser("lint", help="check the public Unreleased entries")
    lint.add_argument("--strict", action="store_true", help="exit non-zero if anything could read better")
    lint.set_defaults(func=cmd_lint)

    # `changelog fixed "..."` works without typing `add`.
    argv = sys.argv[1:]
    if argv and argv[0] not in {"add", "show", "lint", "-h", "--help"}:
        argv = ["add"] + argv

    args = parser.parse_args(argv)
    if not getattr(args, "func", None):
        parser.print_help()
        return
    args.func(args)


if __name__ == "__main__":
    main()
