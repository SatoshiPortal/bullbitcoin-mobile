#!/bin/bash
# ==============================================================================
# Bull Bitcoin Mobile - Reproducibility Test
# Builds the APK twice and compares pre-signature contents.
# If the diff is empty, the build is reproducible.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect container runtime
if command -v podman &> /dev/null; then
    CTR="podman"
elif command -v docker &> /dev/null; then
    CTR="docker"
else
    echo -e "${RED}Error: Neither podman nor docker found.${NC}"
    exit 1
fi
echo "Using $CTR"

# Parse arguments
MODE="${1:-debug}"
if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
    echo "Usage: $0 [debug|release]"
    exit 1
fi

WORK_DIR="$SCRIPT_DIR/reproducibility_test_$(date +%s)"
mkdir -p "$WORK_DIR"
echo "Workspace: $WORK_DIR"

VERIFY_TOOLS_IMAGE="bullbitcoin-verify-tools:latest"

# Build verification tools container
echo "Building verification tools container..."
$CTR build -q -t "$VERIFY_TOOLS_IMAGE" "$SCRIPT_DIR" > /dev/null

# --- Build 1 ---
echo ""
echo -e "${YELLOW}=== Build 1 ===${NC}"
cd "$REPO_ROOT"
CONTAINER="$CTR" make android "$MODE"
cp "$REPO_ROOT/BULL-${MODE}.apk" "$WORK_DIR/build1.apk"

echo "Saved: $WORK_DIR/build1.apk"
sha256sum "$WORK_DIR/build1.apk"

# --- Build 2 (no cache) ---
echo ""
echo -e "${YELLOW}=== Build 2 (no cache) ===${NC}"
# Drop the image so the second build re-runs every step from a clean slate
$CTR rmi bull-app > /dev/null 2>&1 || true

CONTAINER="$CTR" make android "$MODE"
cp "$REPO_ROOT/BULL-${MODE}.apk" "$WORK_DIR/build2.apk"

echo "Saved: $WORK_DIR/build2.apk"
sha256sum "$WORK_DIR/build2.apk"

# --- Compare (authoritative) ---
# Raw per-entry content hash comparison — see compare_apk_entries.sh for why
# this, not a diff of apktool's decoded output, is the actual verdict. Both
# builds are unsigned here (same MODE built twice), so the only legitimate
# exclusion is the same one used everywhere else: legacy JAR signature files.
echo ""
echo "=== Comparing raw entry contents ==="
if raw_diff=$($CTR run --rm \
    -v "$WORK_DIR":/work:ro \
    -v "$SCRIPT_DIR/compare_apk_entries.sh":/compare.sh:ro \
    "$VERIFY_TOOLS_IMAGE" \
    sh /compare.sh /work/build1.apk /work/build2.apk 2>&1); then
    echo -e "${GREEN}BUILD IS REPRODUCIBLE${NC}"
    echo "Both builds are identical (excluding legacy JAR signature files)."
    exit 0
fi

echo -e "${RED}DIFFERENCES FOUND${NC}"
echo "$raw_diff" | tee "$WORK_DIR/raw_diff.txt"

# --- Decode both APKs for a human-readable explanation ---
echo ""
echo -e "${YELLOW}=== Decoding APKs for diagnostic diff ===${NC}"

$CTR run --rm \
    -v "$WORK_DIR":/work \
    "$VERIFY_TOOLS_IMAGE" \
    sh -c "apktool d -f -o /work/decoded1 /work/build1.apk && \
           apktool d -f -o /work/decoded2 /work/build2.apk"

diff_output=$(diff -r -x "MANIFEST.MF" -x "*.RSA" -x "*.SF" -x "*.EC" -x "*.DSA" \
    "$WORK_DIR/decoded1" "$WORK_DIR/decoded2" || true)
echo "$diff_output" | tee "$WORK_DIR/diff.txt"
echo ""
echo "Raw entry diff saved to: $WORK_DIR/raw_diff.txt"
echo "Diagnostic decoded diff saved to: $WORK_DIR/diff.txt"
exit 1
