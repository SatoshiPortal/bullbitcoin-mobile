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

APK_PATH="build/app/outputs/flutter-apk/app-${MODE}.apk"
VERIFY_TOOLS_IMAGE="bullbitcoin-verify-tools:latest"

# Build verification tools container
echo "Building verification tools container..."
$CTR build -q -f "$SCRIPT_DIR/Containerfile" -t "$VERIFY_TOOLS_IMAGE" "$SCRIPT_DIR" > /dev/null

# --- Build 1 ---
echo ""
echo -e "${YELLOW}=== Build 1 ===${NC}"
cd "$REPO_ROOT"
make apk "$MODE"

$CTR create --name repro_build1_$$ bull-build > /dev/null
$CTR cp "repro_build1_$$:/app/$APK_PATH" "$WORK_DIR/build1.apk"
$CTR rm repro_build1_$$ > /dev/null

echo "Saved: $WORK_DIR/build1.apk"
sha256sum "$WORK_DIR/build1.apk"

# --- Build 2 (no cache) ---
echo ""
echo -e "${YELLOW}=== Build 2 (no cache) ===${NC}"
$CTR rmi bull-build > /dev/null 2>&1 || true

make apk "$MODE"

$CTR create --name repro_build2_$$ bull-build > /dev/null
$CTR cp "repro_build2_$$:/app/$APK_PATH" "$WORK_DIR/build2.apk"
$CTR rm repro_build2_$$ > /dev/null

echo "Saved: $WORK_DIR/build2.apk"
sha256sum "$WORK_DIR/build2.apk"

# --- Decode both APKs ---
echo ""
echo -e "${YELLOW}=== Decoding APKs ===${NC}"

$CTR run --rm \
    -v "$WORK_DIR":/work \
    "$VERIFY_TOOLS_IMAGE" \
    sh -c "apktool d -f -o /work/decoded1 /work/build1.apk && \
           apktool d -f -o /work/decoded2 /work/build2.apk"

# --- Compare ---
echo ""
echo "=== Comparing pre-signature contents ==="
diff_output=$(diff -r "$WORK_DIR/decoded1" "$WORK_DIR/decoded2" | grep -v META-INF || true)

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
