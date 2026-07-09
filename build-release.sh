#!/usr/bin/env bash
#
# build-release.sh — cut a Storybook Packager release.
#
# What it does, in order:
#   1. Validate version (semver) + clean git working tree.
#   2. Set MARKETING_VERSION in the Xcode project to match.
#   3. Build the Release configuration (a build phase stamps CFBundleVersion = git commit count).
#   4. Zip the built .app with `ditto` (preserves the bundle/symlinks).
#   5. EdDSA-sign the zip with Sparkle's `sign_update` (key lives in your Keychain).
#   6. Generate the release-notes HTML for this version from CHANGELOG.md's [Unreleased] section.
#   7. Roll CHANGELOG.md: [Unreleased] -> [VERSION] - DATE.
#   8. Insert a new <item> into the Sparkle appcast.xml.
#   9. Update the README version line.
#  10. Commit, create an annotated git tag, push, and open a GitHub release with the zip attached.
#  11. Print a MANUAL upload checklist for media.uwex.edu.
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
UPDATES_DIR="StorybookPackager/updates"
DIST="dist"                              # clean, shallow folder for the finished artifacts you grab
APPCAST="$UPDATES_DIR/appcast.xml"
CHANGELOG="CHANGELOG.md"
README="README.md"
PBXPROJ="$PROJECT/project.pbxproj"
FEED_BASE="https://media.uwex.edu/app/storybook-packager"
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
NOTES_HTML="$UPDATES_DIR/$NOTES_HTML_NAME"

cd "$(dirname "$0")"

# ----------------------------------------------------------------------------------------------
# Preflight
# ----------------------------------------------------------------------------------------------
info "Preflight checks"
command -v xcodebuild >/dev/null || die "xcodebuild not found."
command -v ditto      >/dev/null || die "ditto not found."
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
# 2. Build
# ----------------------------------------------------------------------------------------------
DERIVED="build/release-dd"
info "Building $CONFIG (this also stamps CFBundleVersion from the git commit count)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  clean build CODE_SIGN_STYLE=Automatic | tail -5

APP_PATH="$DERIVED/Build/Products/$CONFIG/$PRODUCT_APP"
[ -d "$APP_PATH" ] || die "Built app not found at $APP_PATH"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
ok "Built $PRODUCT_APP (version $VERSION, build $BUILD_NUMBER)"

# ----------------------------------------------------------------------------------------------
# 3. Build the DMG + sign
# ----------------------------------------------------------------------------------------------
# Sparkle installs DMGs natively (mounts, copies the .app out), so switching the container from
# zip -> dmg does NOT break updates for already-installed clients: same feed, same EdDSA key.
DMG_PATH="$UPDATES_DIR/$DMG_NAME"
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
ok "Signed disk image (length $DMG_LEN)"

# ----------------------------------------------------------------------------------------------
# 4. Release-notes HTML from CHANGELOG (mirrors the existing styled template)
# ----------------------------------------------------------------------------------------------
info "Generating $NOTES_HTML from CHANGELOG"
PUBDATE="$(LC_ALL=en_US.UTF-8 date '+%a, %d %b %Y %H:%M:%S %z')"
# Map Keep-a-Changelog headings -> existing CSS section classes:
#   Added -> new | Changed/Enhanced/Deprecated/Removed/Security -> enhancement | Fixed -> issue
BODY_HTML="$(echo "$NOTES_MD" | awk '
  function flush(){ if(open){print "        </ul>\n    </section>\n"; open=0} }
  /^### /{
    flush(); h=$0; sub(/^### /,"",h)
    cls=(h=="Added")?"new":((h=="Fixed")?"issue":"enhancement")
    printf "    <section class=\"%s\">\n        <ul>\n", cls; open=1; next
  }
  /^[-*] /{ if(open){ line=$0; sub(/^[-*] /,"",line); printf "            <li>%s</li>\n", line } }
  END{ flush() }
')"
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
    </style>
</head>
<body>
$BODY_HTML
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
            <sparkle:releaseNotesLink>$FEED_BASE/$NOTES_HTML_NAME</sparkle:releaseNotesLink>
            <pubDate>$PUBDATE</pubDate>
            <sparkle:minimumSystemVersion>$MIN_SYSTEM_VERSION</sparkle:minimumSystemVersion>
            <enclosure url="$FEED_BASE/$DMG_NAME" sparkle:version="$BUILD_NUMBER" sparkle:shortVersionString="$VERSION" length="$DMG_LEN" type="application/x-apple-diskimage" sparkle:edSignature="$ED_SIG"/>
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
# 7. README version line
# ----------------------------------------------------------------------------------------------
info "Updating README version line"
/usr/bin/sed -i '' -E "s|<sub>.*</sub>|<sub>$VERSION</sub>|" "$README" || true

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
git add -f "$PBXPROJ" "$CHANGELOG" "$README" "$APPCAST" "$NOTES_HTML" "$DMG_PATH"
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
  NOTES_FILE="$(mktemp)"; printf '%s\n' "$NOTES_MD" > "$NOTES_FILE"
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
# 10. Manual upload checklist (no scriptable endpoint for media.uwex.edu)
# ----------------------------------------------------------------------------------------------
cat <<DONE

✓ Release $VERSION prepared.

All artifacts are collected in $DIST/  (app, dmg, appcast, release notes).

NEXT — upload these to $FEED_BASE/  (manual, no automated endpoint):
  • $DIST/$DMG_NAME
  • $DIST/$(basename "$APPCAST")
  • $DIST/$NOTES_HTML_NAME

Until the appcast + dmg are live on media.uwex.edu, Sparkle clients will NOT see the update.
Reminder: distribution uses an Apple Development cert only (no notarization) — users may see
Gatekeeper warnings. Consider setting up Developer ID + notarytool.
DONE
