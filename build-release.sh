#!/usr/bin/env bash
#
# build-release.sh — cut a Storybook Packager release.
#
# What it does, in order:
#   1. Validate version (semver) + clean git working tree.
#   2. Set MARKETING_VERSION in the Xcode project to match, and roll the copyright year range.
#   3. Build the Release configuration (a build phase stamps CFBundleVersion = git commit count).
#   4. Zip the built .app with `ditto` (preserves the bundle/symlinks).
#   5. EdDSA-sign the zip with Sparkle's `sign_update` (key lives in your Keychain).
#   6. Generate the release-notes HTML for this version from CHANGELOG.md's [Unreleased] section.
#   7. Roll CHANGELOG.md: [Unreleased] -> [VERSION] - DATE.
#   8. Insert a new <item> into the Sparkle appcast.xml.
#   9. Update the README version line and its copyright line.
#  10. Commit, create an annotated git tag, push, and open a GitHub release with the zip attached.
#  11. Print where the update is served from.
#
# Hosting: the disk image is a GitHub release asset and the appcast + notes are served by GitHub
# Pages out of docs/ on master. Nothing is uploaded by hand. Builds from 1.9.5 and earlier poll the
# old media.uwex.edu feed, where a one-time copy of the appcast already sits pointing at these same
# absolute URLs; taking that update moves them onto the Pages feed for good.
#
# Distribution caveat: the app is signed with an "Apple Development" cert only — there is NO
# Developer ID signing or notarization, so end users will see Gatekeeper warnings. Fixing that
# (Developer ID Application cert + `xcrun notarytool` + staple) is a separate, recommended task.
#
# Usage:
#   ./build-release.sh 1.1.0                 # cut version 1.1.0
#   ./build-release.sh 1.1.0 --dry-run       # build/sign/generate locally, make NO git/GitHub changes
#   ./build-release.sh 1.1.0 --no-publish    # do everything local incl. commit+tag, but don't push or create the GH release
#
set -euo pipefail

# ----------------------------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------------------------
PROJECT="StorybookPackager/Storybook Packager.xcodeproj"
SCHEME="Storybook Packager"
CONFIG="Release"
PRODUCT_APP="Storybook Packager.app"     # PRODUCT_NAME = $(TARGET_NAME), which has a space
DMG_NAME="StorybookPackager.dmg"         # disk image referenced by the feed (overwritten each release)
VOL_NAME="Storybook Packager"            # mounted-volume name shown in Finder
UPDATES_DIR="StorybookPackager/updates"  # working folder for the built disk image (not committed)
DOCS="docs"                              # published by GitHub Pages from this folder on master
NOTES_DIR="$DOCS/notes"
DIST="dist"                              # clean, shallow folder for the finished artifacts you grab
APPCAST="$DOCS/appcast.xml"
CHANGELOG="CHANGELOG.md"
README="README.md"
PBXPROJ="$PROJECT/project.pbxproj"
INFO_PLIST="StorybookPackager/StorybookPackager/Info.plist"
COPYRIGHT_HOLDER="Universities of Wisconsin Office of Online & Professional Learning Resources"
COPYRIGHT_FROM="2018"                    # year of the first commit; the range runs to the year of the cut
PAGES_BASE="https://uwex-learning-tech.github.io/storybook-packager"   # the Sparkle feed's home
RELEASE_DL="https://github.com/uwex-learning-tech/storybook-packager/releases/download"
FEED_BASE="https://media.uwex.edu/app/storybook-packager"              # the old feed, still mirrored
MIN_SYSTEM_VERSION="10.15"
TAG_PREFIX="v"                            # tags are v-prefixed: v1.1.0

# ----------------------------------------------------------------------------------------------
# Args
# ----------------------------------------------------------------------------------------------
VERSION="${1:-}"
DRY_RUN=0
NO_PUBLISH=0
for arg in "${@:2}"; do
  case "$arg" in
    --dry-run)    DRY_RUN=1 ;;
    --no-publish) NO_PUBLISH=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

die()  { echo "✗ $*" >&2; exit 1; }
info() { echo "→ $*"; }
ok()   { echo "✓ $*"; }

[ -n "$VERSION" ] || die "Usage: $0 <version> [--dry-run] [--no-publish]   (e.g. $0 1.1.0)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Version '$VERSION' is not semver MAJOR.MINOR.PATCH."

TAG="${TAG_PREFIX}${VERSION}"
VERSION_DASHED="$(echo "$VERSION" | tr '.' '-')"          # 1.1.0 -> 1-1-0
NOTES_HTML_NAME="${VERSION_DASHED}.html"
NOTES_HTML="$NOTES_DIR/$NOTES_HTML_NAME"

cd "$(dirname "$0")"

# ----------------------------------------------------------------------------------------------
# Preflight
# ----------------------------------------------------------------------------------------------
info "Preflight checks"
command -v xcodebuild >/dev/null || die "xcodebuild not found."
command -v ditto      >/dev/null || die "ditto not found."
command -v python3    >/dev/null || die "python3 not found (used to render the release notes)."
[ -f "$CHANGELOG" ] || die "$CHANGELOG missing — it is the source of truth for release notes."

if [ "$DRY_RUN" -eq 0 ]; then
  [ -z "$(git status --porcelain)" ] || die "Working tree not clean. Commit or stash first."
fi

# Tag collision guard.
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  die "Tag $TAG already exists. Choose another version or remove the stale tag."
fi

# Locate Sparkle's sign_update (lives under build artifacts or DerivedData; not in git).
SIGN_UPDATE="$(find build "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*Sparkle*/bin/sign_update' -not -path '*old_dsa*' 2>/dev/null | head -1 || true)"
[ -n "$SIGN_UPDATE" ] || die "Could not find Sparkle's sign_update. Build once in Xcode to fetch SwiftPM artifacts."
ok "sign_update: $SIGN_UPDATE"

# Extract the [Unreleased] block from the changelog now, so we fail early if it's empty.
NOTES_MD="$(awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' "$CHANGELOG")"
NOTES_MD="$(echo "$NOTES_MD" | sed -e '/./,$!d' | awk 'NF{p=NR} {a[NR]=$0} END{for(i=1;i<=p;i++) print a[i]}')"
[ -n "$(echo "$NOTES_MD" | tr -d '[:space:]')" ] || die "CHANGELOG.md [Unreleased] section is empty — nothing to release."

echo "── Release plan ──────────────────────────────────────────"
echo "  Version : $VERSION   Tag: $TAG"
echo "  Notes   : $NOTES_HTML  (from CHANGELOG [Unreleased])"
echo "  Mode    : $([ $DRY_RUN -eq 1 ] && echo DRY-RUN || ([ $NO_PUBLISH -eq 1 ] && echo no-publish || echo FULL publish))"
echo "──────────────────────────────────────────────────────────"

# ----------------------------------------------------------------------------------------------
# 1. Set MARKETING_VERSION
# ----------------------------------------------------------------------------------------------
info "Setting MARKETING_VERSION = $VERSION in project"
/usr/bin/sed -i '' -E "s/(MARKETING_VERSION = )[^;]+;/\1$VERSION;/g" "$PBXPROJ"

# ----------------------------------------------------------------------------------------------
# 1b. Copyright notice
# ----------------------------------------------------------------------------------------------
# One string in Info.plist is the whole shipped notice: the welcome window reads
# NSHumanReadableCopyright for the line under the version, and the About box is AppKit's standard
# panel, which reads the same key. Rolled here, before the build, so the app that gets built,
# signed, and shipped carries the year this release was actually cut.
CURRENT_YEAR="$(date +%Y)"
COPYRIGHT_YEARS="$COPYRIGHT_FROM-$CURRENT_YEAR"
COPYRIGHT_LINE="Copyright © $COPYRIGHT_YEARS $COPYRIGHT_HOLDER. All rights reserved."

info "Setting copyright to $COPYRIGHT_YEARS"
# PlistBuddy rather than sed: the holder's name contains an ampersand, which has to be escaped in
# the plist XML, and PlistBuddy writes the value correctly escaped on its own.
/usr/libexec/PlistBuddy -c "Set :NSHumanReadableCopyright $COPYRIGHT_LINE" "$INFO_PLIST" \
  || die "Could not set NSHumanReadableCopyright in $INFO_PLIST"

# ----------------------------------------------------------------------------------------------
# 2. Build
# ----------------------------------------------------------------------------------------------
DERIVED="build/release-dd"
info "Building $CONFIG (this also stamps CFBundleVersion from the git commit count)"
# -destination generic/platform=macOS is REQUIRED for a universal build. Without it, xcodebuild
# resolves the concrete "My Mac" destination and builds ONLY the local machine's architecture
# (this shipped Intel-only releases from the Intel build Mac through 1.5.2), regardless of the
# project's ARCHS setting. ARCHS/ONLY_ACTIVE_ARCH are passed explicitly as a belt-and-suspenders.
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  -destination 'generic/platform=macOS' \
  clean build CODE_SIGN_STYLE=Automatic ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO | tail -5

APP_PATH="$DERIVED/Build/Products/$CONFIG/$PRODUCT_APP"
[ -d "$APP_PATH" ] || die "Built app not found at $APP_PATH"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
# Sparkle compares this against the installed CFBundleVersion to decide whether an update exists, so
# anything but a number means no client is ever offered the release. The "Increment Build Based On
# Git Commits" phase is what replaces the source placeholder; ENABLE_USER_SCRIPT_SANDBOXING = YES
# silently stops it from doing so, and 1.9.8 shipped a feed reading sparkle:version="Auto-incremented
# using git commits" as a result. Refuse to build a feed out of a build number that isn't one.
case "$BUILD_NUMBER" in
  ''|*[!0-9]*)
    die "CFBundleVersion is '$BUILD_NUMBER', not a number — the 'Increment Build Based On Git Commits' build phase did not run. Check ENABLE_USER_SCRIPT_SANDBOXING is NO in the Xcode project." ;;
esac
# Stamped into the bundle by the "Increment Build Based On Git Commits" build phase: the build
# number is a commit count, which does not identify a commit on its own.
SOURCE_COMMIT="$(/usr/libexec/PlistBuddy -c 'Print :SBPSourceCommit' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo unknown)"

# Verify every Mach-O in the bundle is universal before we sign/ship anything.
info "Verifying arm64 + x86_64 slices in the app bundle"
MAIN_BIN="$APP_PATH/Contents/MacOS/Storybook Packager"
for slice in arm64 x86_64; do
  lipo "$MAIN_BIN" -verify_arch "$slice" || die "Main binary is missing the $slice slice: $(lipo -info "$MAIN_BIN")"
done
while IFS= read -r -d '' fw_bin; do
  for slice in arm64 x86_64; do
    lipo "$fw_bin" -verify_arch "$slice" || die "Embedded binary missing $slice slice: $fw_bin"
  done
done < <(find "$APP_PATH/Contents/Frameworks" -type f -perm +111 -print0 2>/dev/null | \
         while IFS= read -r -d '' f; do file -b "$f" | grep -q 'Mach-O' && printf '%s\0' "$f"; done)
ok "Universal binary verified ($(lipo -archs "$MAIN_BIN"))"
ok "Built $PRODUCT_APP (version $VERSION, build $BUILD_NUMBER)"

# ----------------------------------------------------------------------------------------------
# 3. Build the DMG + sign
# ----------------------------------------------------------------------------------------------
# Sparkle installs DMGs natively (mounts, copies the .app out), so switching the container from
# zip -> dmg does NOT break updates for already-installed clients: same feed, same EdDSA key.
DMG_PATH="$UPDATES_DIR/$DMG_NAME"   # gitignored: the release asset is the copy that ships
info "Building disk image with hdiutil -> $DMG_NAME"
# The DMG must contain ONLY the .app at the top level. Do NOT add an /Applications symlink:
# Sparkle < 2.9 (the installed base runs 2.3.2) does not skip symlinks when extracting a DMG —
# it tries to copy every top-level item and fails on the symlink with "error extracting the
# archive". (2.9+ skips auxiliary files, but we must support the older clients we're updating.)
DMG_STAGE="$(mktemp -d)"
ditto "$APP_PATH" "$DMG_STAGE/$PRODUCT_APP"   # ditto preserves the bundle/symlinks faithfully
rm -f "$DMG_PATH"
hdiutil create -volname "$VOL_NAME" -srcfolder "$DMG_STAGE" -ov -format UDZO -quiet "$DMG_PATH"
rm -rf "$DMG_STAGE"
DMG_LEN="$(stat -f%z "$DMG_PATH")"

info "EdDSA-signing the disk image"
SIGN_OUT="$("$SIGN_UPDATE" "$DMG_PATH")"   # -> sparkle:edSignature="..." length="..."
ED_SIG="$(echo "$SIGN_OUT" | sed -E 's/.*sparkle:edSignature="([^"]+)".*/\1/')"
[ -n "$ED_SIG" ] || die "sign_update did not return a signature. Is the private key in your Keychain?"

# Sparkle checks the EdDSA signature itself; this is for anyone verifying a download by hand, so it
# goes everywhere a person might look — the release notes page and the GitHub release body.
DMG_SHA256="$(/usr/bin/shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
[ -n "$DMG_SHA256" ] || die "Could not compute the disk image's SHA-256."
info "Disk image SHA-256: $DMG_SHA256"
ok "Signed disk image (length $DMG_LEN)"

# ----------------------------------------------------------------------------------------------
# 4. Release-notes HTML from CHANGELOG (mirrors the existing styled template)
# ----------------------------------------------------------------------------------------------
info "Generating $NOTES_HTML from CHANGELOG"
PUBDATE="$(LC_ALL=en_US.UTF-8 date '+%a, %d %b %Y %H:%M:%S %z')"
# Map Keep-a-Changelog headings -> existing CSS section classes:
#   Added -> new | Changed/Enhanced/Deprecated/Removed/Security -> enhancement | Fixed -> issue
# CHANGELOG entries are markdown, but they end up inside an HTML page, so they are escaped and
# converted here rather than copied through. Without this an unescaped "<" swallows the rest of a
# sentence as a bogus tag, and a raw entity renders as the character it stands for -- a bullet
# describing an encoding bug as `&#44;` came out as a plain comma, which read as nonsense.
#
# Escaping runs first, then one left-to-right pass converts a small markdown subset. The single
# pass matters: converting code spans and then re-scanning for more would find the backtick left
# inside a ``...`` span's content and pair it with the next one on the line, interleaving tags.
#   & < >              -> entities
#   ``code`` / `code`  -> <code>     (double-backtick form wins; its content may hold a backtick)
#   **bold**           -> <strong>
#   [text](url)        -> <a href>
# Keep-a-Changelog headings map onto the page's existing CSS classes:
#   Added -> new | Changed/Deprecated/Removed/Security/other -> enhancement | Fixed -> issue
#
# The converter is written to a temp file rather than piped inline: it contains backticks, and
# bash parses those as legacy command substitution inside $( ), heredoc or not.
NOTES_PY="$(mktemp -t sbnotes)"
cat > "$NOTES_PY" <<'PYEOF'
import os, re

INLINE = re.compile(
    r"``(?P<code2>.+?)``"
    r"|`(?P<code1>[^`]+)`"
    r"|\*\*(?P<bold>.+?)\*\*"
    r"|\[(?P<text>[^\]]+)\]\((?P<url>[^)]+)\)"
)

def inline(s):
    s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    def sub(m):
        if m.group("code2") is not None:
            return "<code>%s</code>" % m.group("code2")
        if m.group("code1") is not None:
            return "<code>%s</code>" % m.group("code1")
        if m.group("bold") is not None:
            return "<strong>%s</strong>" % m.group("bold")
        return '<a href="%s">%s</a>' % (m.group("url"), m.group("text"))
    return INLINE.sub(sub, s)

CLASSES = {"Added": "new", "Fixed": "issue"}

out = []
items = []
cls = None

def flush():
    if cls is None or not items:
        return
    out.append('    <section class="%s">' % cls)
    out.append("        <ul>")
    out.extend("            <li>%s</li>" % i for i in items)
    out.append("        </ul>")
    out.append("    </section>")
    out.append("")

for line in os.environ["NOTES_MD"].splitlines():
    if line.startswith("### "):
        flush()
        items = []
        cls = CLASSES.get(line[4:].strip(), "enhancement")
    elif cls is not None and (line.startswith("- ") or line.startswith("* ")):
        items.append(inline(line[2:]))

flush()
print("\n".join(out).rstrip("\n"))
PYEOF
BODY_HTML="$(NOTES_MD="$NOTES_MD" python3 "$NOTES_PY")"
rm -f "$NOTES_PY"
[ -n "$BODY_HTML" ] || die "Release notes came out empty — is the CHANGELOG [Unreleased] section formatted as '### Heading' + '- bullet'?"
cat > "$NOTES_HTML" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Storybook Packager $VERSION Release Notes</title>
    <style>
        body { font-size: 14px; line-height: 1.25em; font-family: sans-serif; max-width: 900px; margin: 0 auto; box-sizing: border-box; color: #000; background-color: #fff; }
        section { position: relative; padding: 32px 16px 8px 32px; box-sizing: border-box; }
        section:before { position: absolute; font-size: 24px; font-weight: bold; text-transform: uppercase; top: 20px; left: 10px; }
        section.new { background-color: #f4fff0; } section.new:before { content: "🥳 New Features"; color: #29b935; }
        section.enhancement { background-color: #daf1ff; } section.enhancement:before { content: "✨ Enhancements"; color: #007cb5; }
        section.issue { background-color: #fdffe2; } section.issue:before { content: "🐛 Bugs"; color: #b5a600; }
        section ul { margin: 0; padding: 16px 0 0; } section ul li { margin: 4px 0; }
        .checksum { padding: 16px 32px; font-size: 11px; line-height: 1.6; color: #666; }
        .checksum code { font-family: ui-monospace, Menlo, monospace; word-break: break-all; color: #333; }
    </style>
</head>
<body>
$BODY_HTML
    <p class="checksum">Storybook Packager $VERSION &middot; build $BUILD_NUMBER &middot; commit $SOURCE_COMMIT<br>
    SHA-256 of $DMG_NAME<br><code>$DMG_SHA256</code></p>
</body>
</html>
HTML
ok "Wrote $NOTES_HTML"

# ----------------------------------------------------------------------------------------------
# 5. Roll the CHANGELOG: [Unreleased] -> [VERSION] - DATE, with a fresh empty [Unreleased]
# ----------------------------------------------------------------------------------------------
info "Rolling CHANGELOG [Unreleased] -> [$VERSION]"
ISO_DATE="$(date '+%Y-%m-%d')"
/usr/bin/sed -i '' -E "s/^## \[Unreleased\].*/## [Unreleased]\n\n## [$VERSION] - $ISO_DATE/" "$CHANGELOG"

# ----------------------------------------------------------------------------------------------
# 6. Insert the appcast <item> (newest first, right after <channel>'s <title>)
# ----------------------------------------------------------------------------------------------
info "Inserting appcast <item> into $APPCAST"
ITEM="$(cat <<XML
        <item>
            <title>$VERSION</title>
            <sparkle:releaseNotesLink>$PAGES_BASE/notes/$NOTES_HTML_NAME</sparkle:releaseNotesLink>
            <pubDate>$PUBDATE</pubDate>
            <sparkle:minimumSystemVersion>$MIN_SYSTEM_VERSION</sparkle:minimumSystemVersion>
            <enclosure url="$RELEASE_DL/$TAG/$DMG_NAME" sparkle:version="$BUILD_NUMBER" sparkle:shortVersionString="$VERSION" length="$DMG_LEN" type="application/x-apple-diskimage" sparkle:edSignature="$ED_SIG"/>
        </item>
XML
)"
# Write the item to a temp file and splice it in after the channel <title> line.
TMP_ITEM="$(mktemp)"; printf '%s\n' "$ITEM" > "$TMP_ITEM"
/usr/bin/awk -v f="$TMP_ITEM" '
  /<title>Storybook Packager<\/title>/ && !done { print; while((getline l < f) > 0) print l; done=1; next }
  { print }
' "$APPCAST" > "$APPCAST.tmp" && mv "$APPCAST.tmp" "$APPCAST"
rm -f "$TMP_ITEM"
ok "appcast updated"

# ----------------------------------------------------------------------------------------------
# 7. README version + copyright lines
# ----------------------------------------------------------------------------------------------
info "Updating README version line"
/usr/bin/sed -i '' -E "s|<sub>.*</sub>|<sub>$VERSION</sub>|" "$README" || true

info "Updating README copyright line"
# An unescaped "&" in a sed replacement means "the whole match", and the holder's name has one.
COPYRIGHT_HOLDER_SED="${COPYRIGHT_HOLDER//&/\\&}"
/usr/bin/sed -i '' -E "s|©[0-9]{4}(-[0-9]{4})? .*All rights reserved\.|©$COPYRIGHT_YEARS $COPYRIGHT_HOLDER_SED. All rights reserved.|" "$README" || true

# ----------------------------------------------------------------------------------------------
# 7b. Collect the finished artifacts into a clean, shallow dist/ folder
# ----------------------------------------------------------------------------------------------
# Everything you actually want lands here, at the repo root — no digging through the derived-data
# tree under build/. Rebuilt fresh each run so it only ever holds the current release.
info "Collecting artifacts into $DIST/"
rm -rf "$DIST"
mkdir -p "$DIST"
ditto "$APP_PATH" "$DIST/$PRODUCT_APP"    # the built .app (lifted out of build/release-dd/…)
cp "$DMG_PATH"   "$DIST/"                  # signed disk image (the Sparkle enclosure)
cp "$APPCAST"    "$DIST/"                  # Sparkle feed
cp "$NOTES_HTML" "$DIST/"                  # release-notes page
ok "Artifacts in $DIST/ — $PRODUCT_APP, $DMG_NAME, $(basename "$APPCAST"), $NOTES_HTML_NAME"

if [ "$DRY_RUN" -eq 1 ]; then
  echo ""
  ok "DRY-RUN complete. Built/signed/generated locally; no git or GitHub changes were made."
  echo "  Artifacts collected in $DIST/  (app, dmg, appcast, release notes)"
  echo "  (git working tree was modified — 'git checkout -- .' to revert, or inspect with 'git diff')"
  exit 0
fi

# ----------------------------------------------------------------------------------------------
# 8. Commit + tag  (plain commit/tag messages, no author attribution — by project policy)
# ----------------------------------------------------------------------------------------------
info "Committing release artifacts"
# -f because the .xcodeproj dir matches a *.xcodeproj ignore rule; project.pbxproj is tracked
# and intentional to commit, so force past the (benign) ignore warning that would else abort.
git add -f "$PBXPROJ" "$INFO_PLIST" "$CHANGELOG" "$README" "$APPCAST" "$NOTES_HTML"
git commit -m "Release $VERSION"
git tag -a "$TAG" -m "Storybook Packager $VERSION"
ok "Committed and tagged $TAG"

if [ "$NO_PUBLISH" -eq 1 ]; then
  echo ""
  ok "no-publish: committed + tagged locally. Not pushed, no GitHub release created."
  echo "  When ready: git push && git push origin $TAG && create the GitHub release manually."
else
  # ------------------------------------------------------------------------------------------
  # 9. Push + GitHub release
  # ------------------------------------------------------------------------------------------
  info "Pushing and creating GitHub release"
  git push
  git push origin "$TAG"
  # Release body = the version's changelog section (markdown), via a temp notes file.
  NOTES_FILE="$(mktemp)"
  printf '%s\n' "$NOTES_MD" > "$NOTES_FILE"
  printf '\n---\n\nBuild %s from commit `%s`.\n\n`%s`\nSHA-256 `%s`\n' \
    "$BUILD_NUMBER" "$SOURCE_COMMIT" "$DMG_NAME" "$DMG_SHA256" >> "$NOTES_FILE"
  if command -v gh >/dev/null 2>&1; then
    gh release create "$TAG" "$DMG_PATH" \
      --title "Storybook Packager $VERSION" \
      --notes-file "$NOTES_FILE"
    ok "GitHub release $TAG created"
  else
    echo "  gh not installed — create the release manually for tag $TAG (notes in CHANGELOG)."
  fi
  rm -f "$NOTES_FILE"
fi

# ----------------------------------------------------------------------------------------------
# 10. Where the update comes from
# ----------------------------------------------------------------------------------------------
cat <<DONE

✓ Release $VERSION prepared.

All artifacts are collected in $DIST/  (app, dmg, appcast, release notes).

The update serves itself now:
  • disk image  -> $RELEASE_DL/$TAG/$DMG_NAME   (attached to the release just created)
  • feed        -> $PAGES_BASE/appcast.xml      (GitHub Pages, from $DOCS/ on master)
  • notes       -> $PAGES_BASE/notes/$NOTES_HTML_NAME
Pages redeploys on push; give it a minute, then load the feed URL to confirm.

NOTHING TO UPLOAD. Every URL a client needs is absolute and already live:
the disk image is the asset on this release, the notes are on Pages, and the feed is on Pages.

The old feed at $FEED_BASE/appcast.xml is a one-time gateway that was already put in place, and
it does not need refreshing: builds from 1.9.5 and earlier poll it, are offered the version it
advertises, and once installed follow $PAGES_BASE instead, because that is the feed compiled into
them. Re-upload $DIST/$(basename "$APPCAST") there only if you want those stragglers taken
straight to the newest version rather than chain-updating through the one it already names.

SHA-256 of $DMG_NAME:
  $DMG_SHA256

Reminder: distribution uses an Apple Development cert only (no notarization) — users may see
Gatekeeper warnings. Consider setting up Developer ID + notarytool.
DONE
