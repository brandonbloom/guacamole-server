#!/bin/bash
# Attaches the packages in DIST to the GitHub release for TAG, creating the
# release if needed. Usage: scripts/macos-publish.sh TAG DIST
set -euo pipefail
tag="${1:?usage: scripts/macos-publish.sh TAG DIST}"
dist="${2:?usage: scripts/macos-publish.sh TAG DIST}"
gh release view "$tag" >/dev/null 2>&1 ||
    gh release create "$tag" --verify-tag --title "$tag" --notes "guacd $tag for macOS (VNC only). See README.md."
gh release upload "$tag" "$dist"/*.tar.gz "$dist"/*.sha256 --clobber
