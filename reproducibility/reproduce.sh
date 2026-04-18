#!/bin/bash
# Reproduce a build from a manifest file
# Usage: ./reproduce.sh <manifest.json>
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <manifest.json>"
    exit 1
fi

MANIFEST="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: brew install jq"
    exit 1
fi

# Parse manifest
GIT_COMMIT=$(jq -r '.git_commit' "$MANIFEST")
BUILD_MODE=$(jq -r '.build_mode' "$MANIFEST")
BUILD_FORMAT=$(jq -r '.build_format' "$MANIFEST")
RUST_VERSION=$(jq -r '.rust' "$MANIFEST")
FLUTTER_VERSION=$(jq -r '.flutter' "$MANIFEST")
EXPECTED_LOCK_SHA=$(jq -r '.pubspec_lock_sha256' "$MANIFEST")

echo "Reproducing build from manifest:"
echo "  Commit:  $GIT_COMMIT"
echo "  Mode:    $BUILD_MODE"
echo "  Rust:    $RUST_VERSION"
echo "  Flutter: $FLUTTER_VERSION"

# Checkout exact commit
cd "$REPO_ROOT"
git checkout "$GIT_COMMIT"

# Verify pubspec.lock checksum
ACTUAL_LOCK_SHA=$(sha256sum "$REPO_ROOT/pubspec.lock" | awk '{print $1}')
if [ "$ACTUAL_LOCK_SHA" != "$EXPECTED_LOCK_SHA" ]; then
    echo "ERROR: pubspec.lock mismatch"
    echo "  Expected: $EXPECTED_LOCK_SHA"
    echo "  Actual:   $ACTUAL_LOCK_SHA"
    git checkout -
    exit 1
fi
echo "  pubspec.lock: OK"

# Build
make container-tools FLUTTER_VERSION="$FLUTTER_VERSION" EXPECTED_RUST_VERSION="$RUST_VERSION"
make container-app
make apk "$BUILD_MODE" FORMAT="$BUILD_FORMAT"

# Return to original branch
git checkout -
