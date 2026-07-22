#!/usr/bin/env bash
#
# Bump the app version in pubspec.yaml, commit it, and tag the commit.
#
#   tool/release.sh beta      1.0.0-beta.3  -> 1.0.0-beta.4
#   tool/release.sh release   1.0.0-beta.4  -> 1.0.0
#   tool/release.sh patch     1.0.0         -> 1.0.1
#   tool/release.sh minor     1.0.1         -> 1.1.0
#   tool/release.sh major     1.1.0         -> 2.0.0
#   tool/release.sh show      print the current version and build number
#
# Flags: --dry-run (print what would change), --no-tag (commit without tagging).
#
# The `+N` build metadata in pubspec.yaml is the committed *floor* for the
# platform build number; the real build number is the git commit count, applied
# at build time (android/app/build.gradle, and the "Set Build Number From Git"
# Xcode phase). This script keeps the floor in step with the commit count, so a
# rewritten history can never produce a build number below the last release.
set -euo pipefail

cd "$(dirname "$0")/.."

PUBSPEC=pubspec.yaml
DRY_RUN=0
TAG=1
CMD=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-tag)  TAG=0 ;;
    -h|--help) sed -n '3,17p' "$0" | sed 's/^# \?//'; exit 0 ;;
    patch|minor|major|release|alpha|beta|rc|show) CMD="$arg" ;;
    *) echo "error: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

if [ -z "$CMD" ]; then
  echo "error: missing command (try --help)" >&2
  exit 2
fi

# --- read current version -----------------------------------------------------
version_line=$(grep -E '^version:' "$PUBSPEC" | head -1)
current=${version_line#version:}
current=$(echo "$current" | tr -d '[:space:]')

if [[ ! "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-([0-9A-Za-z.-]+))?(\+([0-9]+))?$ ]]; then
  echo "error: cannot parse version '$current' in $PUBSPEC" >&2
  exit 1
fi
major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
pre="${BASH_REMATCH[5]}"
floor="${BASH_REMATCH[7]:-1}"

commit_count=$(git rev-list --count HEAD)

if [ "$CMD" = "show" ]; then
  echo "pubspec version : $current"
  echo "semver          : ${major}.${minor}.${patch}${pre:+-$pre}"
  echo "build floor     : $floor"
  echo "commit count    : $commit_count  <- the build number an APK/IPA gets now"
  latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "(none)")
  echo "latest tag      : $latest_tag"
  exit 0
fi

# --- compute the next version -------------------------------------------------
bump_prerelease() {
  local label="$1"
  if [[ "$pre" =~ ^${label}\.([0-9]+)$ ]]; then
    pre="${label}.$(( ${BASH_REMATCH[1]} + 1 ))"
  elif [ "$pre" = "$label" ]; then
    pre="${label}.2"
  elif [ -n "$pre" ]; then
    # Switching tracks, e.g. alpha -> beta: restart the counter, same X.Y.Z.
    pre="${label}.1"
  else
    # Starting a prerelease from a shipped version: it precedes the next patch.
    patch=$(( patch + 1 ))
    pre="${label}.1"
  fi
}

case "$CMD" in
  major)   major=$(( major + 1 )); minor=0; patch=0; pre="" ;;
  minor)   minor=$(( minor + 1 )); patch=0; pre="" ;;
  patch)   patch=$(( patch + 1 )); pre="" ;;
  release)
    if [ -z "$pre" ]; then
      echo "error: $current is already a stable version; use patch/minor/major" >&2
      exit 1
    fi
    pre=""
    ;;
  alpha|beta|rc) bump_prerelease "$CMD" ;;
esac

# The release commit itself adds one to the count, so that is the new floor.
new_floor=$(( commit_count + 1 ))
new_version="${major}.${minor}.${patch}${pre:+-$pre}"
new_line="version: ${new_version}+${new_floor}"
tag="v${new_version}"

echo "  $current  ->  ${new_version}+${new_floor}"
[ "$TAG" -eq 1 ] && echo "  tag: $tag"

# --- guards -------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  echo "(dry run — nothing written)"
  exit 0
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree is dirty; commit or stash first" >&2
  exit 1
fi
if [ "$TAG" -eq 1 ] && git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "error: tag $tag already exists" >&2
  exit 1
fi

# --- apply --------------------------------------------------------------------
tmp=$(mktemp)
sed "s|^version:.*|${new_line}|" "$PUBSPEC" > "$tmp"
mv "$tmp" "$PUBSPEC"

git add "$PUBSPEC"
git commit -q -m "Release ${new_version}"
if [ "$TAG" -eq 1 ]; then
  git tag -a "$tag" -m "$new_version"
  echo "tagged $tag at $(git rev-parse --short HEAD)"
fi

echo
echo "Version is now ${new_version}, build $(git rev-list --count HEAD)."
echo "Next: flutter build appbundle --release   (then: git push && git push --tags)"
