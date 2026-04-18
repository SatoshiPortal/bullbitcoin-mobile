#!/bin/bash
# Reproduce a build from a manifest file
# Usage: ./reproduce.sh <manifest.json>
set -euo pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <manifest.json>"
    exit 1
fi

MANIFEST="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required. Install with: brew install jq${NC}"
    exit 1
fi

# Parse manifest
GIT_COMMIT=$(jq -r '.git_commit' "$MANIFEST")
GIT_BRANCH=$(jq -r '.git_branch' "$MANIFEST")
BUILD_MODE=$(jq -r '.build_mode' "$MANIFEST")
BUILD_FORMAT=$(jq -r '.build_format' "$MANIFEST")
RUST_VERSION=$(jq -r '.rust' "$MANIFEST")
FLUTTER_VERSION=$(jq -r '.flutter' "$MANIFEST")
EXPECTED_LOCK_SHA=$(jq -r '.pubspec_lock_sha256' "$MANIFEST")
EXPECTED_APK_SHA=$(jq -r '.apk_sha256' "$MANIFEST")
SHORT_COMMIT=$(jq -r '.git_commit_short' "$MANIFEST")

echo "=========================================="
echo "  Reproducing build from manifest"
echo "=========================================="
echo "  Commit:  $GIT_COMMIT ($GIT_BRANCH)"
echo "  Mode:    $BUILD_MODE"
echo "  Format:  $BUILD_FORMAT"
echo "  Rust:    $RUST_VERSION"
echo "  Flutter: $FLUTTER_VERSION"
echo "=========================================="

# Checkout exact commit
echo ""
echo -e "${YELLOW}Checking out commit $GIT_COMMIT...${NC}"
cd "$REPO_ROOT"
git checkout "$GIT_COMMIT"

# Verify pubspec.lock checksum
echo ""
echo "Verifying pubspec.lock checksum..."
ACTUAL_LOCK_SHA=$(sha256sum "$REPO_ROOT/pubspec.lock" | awk '{print $1}')
if [ "$ACTUAL_LOCK_SHA" != "$EXPECTED_LOCK_SHA" ]; then
    echo -e "${RED}ERROR: pubspec.lock checksum mismatch!${NC}"
    echo "  Expected: $EXPECTED_LOCK_SHA"
    echo "  Actual:   $ACTUAL_LOCK_SHA"
    echo "  Dependencies have changed since the original build."
    exit 1
fi
echo -e "${GREEN}pubspec.lock checksum matches${NC}"

# Build with pinned versions
echo ""
echo -e "${YELLOW}Building with pinned tool versions...${NC}"
make container-tools FLUTTER_VERSION="$FLUTTER_VERSION" EXPECTED_RUST_VERSION="$RUST_VERSION"
make container-app
make apk "$BUILD_MODE" FORMAT="$BUILD_FORMAT"

# Compare APK hash
echo ""
echo "Comparing APK hashes..."
BUILT_APK="output/BULL-${SHORT_COMMIT}-${BUILD_MODE}.apk"

if [ ! -f "$BUILT_APK" ]; then
    echo -e "${RED}ERROR: Built APK not found at $BUILT_APK${NC}"
    exit 1
fi

ACTUAL_APK_SHA=$(sha256sum "$BUILT_APK" | awk '{print $1}')

echo ""
echo "=========================================="
if [ "$ACTUAL_APK_SHA" = "$EXPECTED_APK_SHA" ]; then
    echo -e "  ${GREEN}REPRODUCIBLE: APK hashes match${NC}"
else
    echo -e "  ${RED}MISMATCH: APK hashes differ${NC}"
    echo "  Expected: $EXPECTED_APK_SHA"
    echo "  Actual:   $ACTUAL_APK_SHA"
fi
echo "=========================================="

# Return to original branch
git checkout -
