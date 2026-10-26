#!/bin/bash
# Usage: scripts/release.sh [patch|minor|major|X.Y.Z]
# Bumps VERSION, builds the DMG, tags, pushes, and creates a GitHub release.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CURRENT="$(tr -d '[:space:]' < VERSION)"
IFS=. read -r MAJOR MINOR PATCH <<<"$CURRENT"
NEXT_PATCH="$MAJOR.$MINOR.$((PATCH + 1))"
NEXT_MINOR="$MAJOR.$((MINOR + 1)).0"
NEXT_MAJOR="$((MAJOR + 1)).0.0"

CHOICE="${1:-}"
if [ -z "$CHOICE" ]; then
    echo "Current version: $CURRENT"
    echo "  1) patch  → $NEXT_PATCH"
    echo "  2) minor  → $NEXT_MINOR"
    echo "  3) major  → $NEXT_MAJOR"
    echo "  or type a version like 1.2.3"
    read -r -p "Choose: " CHOICE
fi

case "$CHOICE" in
    1|patch) NEW="$NEXT_PATCH" ;;
    2|minor) NEW="$NEXT_MINOR" ;;
    3|major) NEW="$NEXT_MAJOR" ;;
    *) NEW="${CHOICE#v}" ;;
esac

[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid version: $NEW" >&2; exit 1; }
TAG="v$NEW"
git rev-parse "$TAG" >/dev/null 2>&1 && { echo "Tag $TAG already exists" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Working tree is not clean; commit or stash first" >&2; exit 1; }
[ "$(git branch --show-current)" = "main" ] || { echo "Releases must be made from main" >&2; exit 1; }

read -r -p "Release $TAG (current $CURRENT)? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

echo "$NEW" > VERSION
./scripts/build-dmg.sh
DMG="dist/LightBringer-$NEW.dmg"

git add VERSION
git commit -m "Release $TAG"
git tag "$TAG"
git push origin main "$TAG"

gh release create "$TAG" "$DMG" --title "Light Bringer $NEW" --generate-notes
echo "Released $TAG"
