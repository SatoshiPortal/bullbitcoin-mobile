#!/bin/bash
# Build APK and generate manifest inside the container
# Usage: build_and_manifest.sh <mode> <format> <gradle_heap>
set -euo pipefail

MODE="${1:-debug}"
FORMAT="${2:-apk}"
GRADLE_HEAP="${3:-4g}"

# Reproducibility env
SOURCE_DATE_EPOCH=$(git -C /app log -1 --format=%ct)
CARGO_ENCODED_RUSTFLAGS=$(printf '%s\037%s\037%s' \
    "--remap-path-prefix=$HOME/.cargo=/cargo" \
    "--remap-path-prefix=$HOME/.rustup=/rustup" \
    "--remap-path-prefix=/app=/build")
export SOURCE_DATE_EPOCH CARGO_ENCODED_RUSTFLAGS

# Gradle config
mkdir -p "$HOME/.gradle"
cat > "$HOME/.gradle/gradle.properties" << EOF
org.gradle.daemon=false
org.gradle.jvmargs=-Xmx${GRADLE_HEAP}
org.gradle.parallel=true
org.gradle.caching=true
EOF

# Build
fvm flutter build "$FORMAT" --"$MODE"

# Info
SHORT_COMMIT=$(git -C /app rev-parse --short=7 HEAD)
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_DATE_SHORT=$(date -u +%Y%m%d)
APK_PATH="build/app/outputs/flutter-apk/app-${MODE}.apk"
APK_SHA256=$(sha256sum "$APK_PATH" | awk '{print $1}')

echo ""
echo "=========================================="
echo " SHA256: $APK_SHA256"
echo "=========================================="
echo ""

STEM="bull-${MODE}-${BUILD_DATE_SHORT}-${SHORT_COMMIT}"

# Output to /app/output (container-owned, no permission issues)
mkdir -p /app/output
cp "$APK_PATH" "/app/output/${STEM}.apk"

# Generate manifest
cat > "/app/output/${STEM}.json" << EOF
{
  "git_commit": "$(git -C /app rev-parse HEAD)",
  "git_branch": "$(git -C /app rev-parse --abbrev-ref HEAD)",
  "git_commit_short": "${SHORT_COMMIT}",
  "build_date": "${BUILD_DATE}",
  "build_mode": "${MODE}",
  "build_format": "${FORMAT}",
  "rust": "$(rustc --version | awk '{print $2}')",
  "flutter": "$(fvm flutter --version --machine 2>/dev/null | grep frameworkVersion | cut -d'"' -f4)",
  "dart": "$(fvm dart --version 2>&1 | awk '{print $4}')",
  "java": "$(java --version 2>&1 | head -1)",
  "android_ndk": "$(ls "$ANDROID_HOME"/ndk/ 2>/dev/null | head -1)",
  "android_build_tools": "$(ls "$ANDROID_HOME"/build-tools/ 2>/dev/null | head -1)",
  "pubspec_lock_sha256": "$(sha256sum /app/pubspec.lock | awk '{print $1}')",
  "source_date_epoch": "${SOURCE_DATE_EPOCH}",
  "apk_sha256": "${APK_SHA256}"
}
EOF

echo "✅  APK:      ${STEM}.apk"
echo "✅  Manifest: ${STEM}.json"
