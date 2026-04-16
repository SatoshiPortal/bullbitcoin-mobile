#!/usr/bin/env bash
# ==============================================================================
# Bull Bitcoin Mobile - Reproducibility Test
# Builds the APK twice and compares pre-signature contents.
# If the diff is empty, the build is reproducible.
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BASE_IMAGE="bull-mobile"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if command -v podman &> /dev/null; then
    CTR="podman"
elif command -v docker &> /dev/null; then
    CTR="docker"
else
    echo -e "${RED}Error: Neither podman nor docker found.${NC}"
    exit 1
fi
echo "Using $CTR"

MODE="${1:-debug}"
if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
    echo "Usage: $0 [debug|release]"
    exit 1
fi

WORK_DIR="$REPO_ROOT/reproducibility_test_$(date +%s)"
mkdir -p "$WORK_DIR"
echo "Workspace: $WORK_DIR"

cd "$REPO_ROOT"

# --- Build 1 ---
echo ""
echo -e "${YELLOW}=== Build 1 ===${NC}"
rm -rf build
make build "$MODE"
cp "$REPO_ROOT/app-${MODE}.apk" "$WORK_DIR/build1.apk"

echo "Saved: $WORK_DIR/build1.apk"
sha256sum "$WORK_DIR/build1.apk"

# --- Build 2 ---
echo ""
echo -e "${YELLOW}=== Build 2 ===${NC}"
rm -rf build
make build "$MODE"
cp "$REPO_ROOT/app-${MODE}.apk" "$WORK_DIR/build2.apk"

echo "Saved: $WORK_DIR/build2.apk"
sha256sum "$WORK_DIR/build2.apk"

# --- Decode both APKs ---
echo ""
echo -e "${YELLOW}=== Decoding APKs ===${NC}"

$CTR run --rm \
    -v "$WORK_DIR":/work \
    "$BASE_IMAGE" \
    sh -c "apktool d -f -o /work/decoded1 /work/build1.apk && \
           apktool d -f -o /work/decoded2 /work/build2.apk"

# --- Compare ---
echo ""
echo "=== Comparing pre-signature contents ==="
diff_output=$(diff -r "$WORK_DIR/decoded1" "$WORK_DIR/decoded2" | grep -vE 'META-INF|apktool\.yml' || true)

if [[ -z "$diff_output" ]]; then
    echo -e "${GREEN}BUILD IS REPRODUCIBLE${NC}"
    echo "Both builds are identical (excluding META-INF signatures)."
    exit 0
else
    echo -e "${RED}DIFFERENCES FOUND${NC}"
    echo "$diff_output" | tee "$WORK_DIR/diff.txt"
    echo ""
    echo "Full diff saved to: $WORK_DIR/diff.txt"
    exit 1
fi
