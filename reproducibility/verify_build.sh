#!/bin/bash
# ==============================================================================
# Bull Bitcoin Mobile - Reproducible Build Verification Script
# ==============================================================================
#
# Verifies that Bull Bitcoin Mobile builds are reproducible by:
# 1. Building the app from source using the root Dockerfile
# 2. Comparing the built APK/AAB against the official release
# 3. Reporting whether the build is reproducible
#
# Usage: ./verify_build.sh --version <version> [--apk <path>]
#
# Paths:
#   - GitHub APK: Downloads universal APK, builds APK, compares directly
#   - Play Store: Uses split APKs from device, builds AAB, extracts splits, compares
#
# Requirements: Docker or Podman, 8GB+ RAM, 50GB+ disk space
#
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Error handling
on_error() {
    local exit_code=$?
    local line_no=$1
    echo -e "${RED}Script failed at line $line_no with exit code $exit_code${NC}"
    if [[ -n "${container_name:-}" ]]; then
        $CONTAINER_CMD rm -f "$container_name" 2>/dev/null || true
    fi
}
trap 'on_error $LINENO' ERR

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

# Detect container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
    echo "Using Podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
    echo "Using Docker"
else
    echo -e "${RED}Error: Neither podman nor docker found.${NC}"
    exit 1
fi

# Helper: Run apktool in container
containerApktool() {
    local targetFolder="$1"
    local app="$2"
    local targetFolderParent=$(dirname "$targetFolder")
    local targetFolderBase=$(basename "$targetFolder")
    local appFolder=$(dirname "$app")
    local appFile=$(basename "$app")

    $CONTAINER_CMD run --rm --user root \
        -v "$targetFolderParent":/tfp \
        -v "$appFolder":/af:ro \
        docker.io/walletscrutiny/android:5 \
        sh -c "apktool d -f -o /tfp/$targetFolderBase /af/$appFile"
}

# Helper: Get signer certificate SHA-256
getSigner() {
    local apkFile="$1"
    local dir=$(dirname "$apkFile")
    local base=$(basename "$apkFile")
    $CONTAINER_CMD run --rm \
        -v "$dir":/mnt:ro \
        -w /mnt \
        docker.io/walletscrutiny/android:5 \
        apksigner verify --print-certs "$base" 2>/dev/null | grep "Signer #1 certificate SHA-256" | awk '{print $6}'
}

# Helper: Check system memory
check_memory() {
    local available_mem_gb=$(free -g | awk '/^Mem:/ {print $7}')
    local total_mem_gb=$(free -g | awk '/^Mem:/ {print $2}')
    echo "Memory: ${available_mem_gb}GB available / ${total_mem_gb}GB total"
    if [[ $available_mem_gb -lt 4 ]]; then
        echo -e "${YELLOW}Warning: Low memory. Build may fail.${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
}

usage() {
    cat <<'EOF'
Usage: verify_build.sh --version <version> [OPTIONS]

OPTIONS:
    --version <version>   App version to build (required, e.g., 6.5.2)
    --apk <path>          Path to official APK or directory with split APKs
                          If omitted: downloads universal APK from GitHub
                          If file: single APK comparison
                          If directory: split APK comparison (Play Store path)
    --cleanup             Remove workspace after completion
    --help                Show this help

EXAMPLES:
    # Verify against GitHub release
    ./verify_build.sh --version 6.5.2

    # Verify against Play Store (split APKs extracted from device)
    ./verify_build.sh --version 6.5.2 --apk ~/bullbitcoin-splits/

    # Verify against local APK file
    ./verify_build.sh --version 6.5.2 --apk ./official.apk
EOF
}

# Parse arguments
appVersion=""
apkPath=""
shouldCleanup=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) appVersion="$2"; shift ;;
        --apk) apkPath="$2"; shift ;;
        --cleanup) shouldCleanup=true ;;
        --help) usage; exit 0 ;;
        *) echo "Unknown argument: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ -z "$appVersion" ]]; then
    echo -e "${RED}Error: --version is required${NC}"
    usage
    exit 1
fi

# Determine verification mode
verificationMode=""
apkDir=""

if [[ -z "$apkPath" ]]; then
    verificationMode="github"
    echo "=== Mode: GitHub Universal APK ==="
elif [[ -f "$apkPath" ]]; then
    verificationMode="github"
    echo "=== Mode: Single APK File ==="
    apkDir=$(mktemp -d)
    cp "$apkPath" "$apkDir/base.apk"
elif [[ -d "$apkPath" ]]; then
    verificationMode="device"
    echo "=== Mode: Play Store Split APKs ==="
    apkDir="$apkPath"
    if [[ ! -f "$apkDir/base.apk" ]]; then
        echo -e "${RED}Error: base.apk not found in $apkDir${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: $apkPath not found${NC}"
    exit 1
fi

# Setup workspace
workDir="$SCRIPT_DIR/bullbitcoin_${appVersion}_verification"
if [[ -d "$workDir" ]]; then
    echo -e "${YELLOW}Workspace exists. Remove first: rm -rf $workDir${NC}"
    exit 1
fi
mkdir -p "$workDir"
workDir=$(cd "$workDir" && pwd)
echo "Workspace: $workDir"

# Extract metadata from official APK (device mode)
appId="com.bullbitcoin.mobile"
officialVersion="$appVersion"
versionCode=""
appHash=""
signer=""

if [[ "$verificationMode" == "device" ]]; then
    echo "Extracting metadata from base.apk..."
    tempDir=$(mktemp -d)
    containerApktool "$tempDir" "$apkDir/base.apk"

    appId=$(grep 'package=' "$tempDir/AndroidManifest.xml" | sed 's/.*package="//g' | sed 's/".*//g')
    officialVersion=$(grep 'versionName' "$tempDir/apktool.yml" | awk '{print $2}' | tr -d "'")
    versionCode=$(grep 'versionCode' "$tempDir/apktool.yml" | awk '{print $2}' | tr -d "'")
    rm -rf "$tempDir"

    if [[ "$appId" != "com.bullbitcoin.mobile" ]]; then
        echo -e "${RED}Error: Unexpected appId: $appId${NC}"
        exit 2
    fi

    appHash=$(sha256sum "$apkDir/base.apk" | awk '{print $1}')
    signer=$(getSigner "$apkDir/base.apk")

    echo "App ID: $appId"
    echo "Version: $officialVersion ($versionCode)"
    echo "Hash: $appHash"
    echo "Signer: $signer"
fi

# Generate device-spec.json for Play Store path
if [[ "$verificationMode" == "device" ]]; then
    echo "Generating device-spec.json..."

    # Detect ABIs from split APK filenames
    abis=()
    for split in "$apkDir"/split_config.*.apk; do
        [[ -f "$split" ]] || continue
        if [[ $(basename "$split") =~ split_config\.(arm64_v8a|armeabi-v7a|x86|x86_64)\.apk ]]; then
            abi="${BASH_REMATCH[1]//_/-}"
            abis+=("\"$abi\"")
        fi
    done
    [[ ${#abis[@]} -eq 0 ]] && abis=("\"arm64-v8a\"")

    # Detect screen density
    density=480
    for split in "$apkDir"/split_config.*.apk; do
        [[ -f "$split" ]] || continue
        case $(basename "$split") in
            *ldpi*) density=120 ;; *mdpi*) density=160 ;;
            *hdpi*) density=240 ;; *xhdpi*) density=320 ;;
            *xxhdpi*) density=480 ;; *xxxhdpi*) density=640 ;;
        esac
    done

    cat > "$workDir/device-spec.json" <<EOF
{
    "supportedAbis": [$(IFS=,; echo "${abis[*]}")],
    "supportedLocales": ["en"],
    "screenDensity": $density,
    "sdkVersion": 31
}
EOF
    echo "Created: $workDir/device-spec.json"
fi

# Download GitHub APK if needed
if [[ "$verificationMode" == "github" && -z "$apkDir" ]]; then
    echo "Downloading official APK from GitHub..."
    apkDir="$workDir"
    releaseJson=$(curl -sL "https://api.github.com/repos/SatoshiPortal/bullbitcoin-mobile/releases/tags/v${appVersion}")
    apkUrl=$(echo "$releaseJson" | grep -o "https://github.com/SatoshiPortal/bullbitcoin-mobile/releases/download/v${appVersion}/[^\"]*\\.apk" | head -n1)

    if [[ -z "$apkUrl" ]]; then
        echo -e "${RED}Error: APK not found in GitHub release v${appVersion}${NC}"
        exit 1
    fi

    wget -q "$apkUrl" -O "$workDir/official.apk"
    echo "Downloaded: $workDir/official.apk"

    # Extract metadata
    tempDir=$(mktemp -d)
    containerApktool "$tempDir" "$workDir/official.apk"
    officialVersion=$(grep 'versionName' "$tempDir/apktool.yml" | awk '{print $2}' | tr -d "'" || echo "$appVersion")
    versionCode=$(grep 'versionCode' "$tempDir/apktool.yml" | awk '{print $2}' | tr -d "'" || echo "unknown")
    rm -rf "$tempDir"

    appHash=$(sha256sum "$workDir/official.apk" | awk '{print $1}')
    signer=$(getSigner "$workDir/official.apk")
fi

echo ""
check_memory
echo ""

# Build using root Dockerfile
echo "=== Building from source ==="
echo "This may take 30-60 minutes..."

buildFormat="apk"
[[ "$verificationMode" == "device" ]] && buildFormat="aab"

cd "$REPO_ROOT"
$CONTAINER_CMD build \
    --network=host \
    --build-arg VERSION="v${appVersion}" \
    --build-arg MODE=release \
    --build-arg FORMAT="$buildFormat" \
    --build-arg SOURCE=github \
    -t bullbitcoin-verify:v${appVersion} \
    .

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Build failed${NC}"
    exit 1
fi

echo "Build complete"

# Extract built artifact
echo "Extracting built artifact..."
container_name="bullbitcoin_extract_$$"
containerId=$($CONTAINER_CMD create --name "$container_name" bullbitcoin-verify:v${appVersion})

if [[ "$verificationMode" == "github" ]]; then
    $CONTAINER_CMD cp "$containerId:/app/build/app/outputs/flutter-apk/app-release.apk" "$workDir/built.apk"
else
    $CONTAINER_CMD cp "$containerId:/app/build/app/outputs/bundle/release/app-release.aab" "$workDir/built.aab"
fi

# Extract git info
$CONTAINER_CMD start "$containerId"
$CONTAINER_CMD exec "$containerId" sh -c "cd /app && git rev-parse HEAD" > "$workDir/commit.txt" 2>/dev/null || echo "unknown" > "$workDir/commit.txt"
$CONTAINER_CMD rm -f "$containerId"
container_name=""

commit=$(cat "$workDir/commit.txt")
echo "Built from commit: $commit"

# Compare
echo ""
echo "=== Comparing builds ==="

if [[ "$verificationMode" == "github" ]]; then
    # Direct APK comparison
    officialApk="$workDir/official.apk"
    [[ -f "$apkDir/base.apk" ]] && officialApk="$apkDir/base.apk"

    mkdir -p "$workDir/official-decoded" "$workDir/built-decoded"
    containerApktool "$workDir/official-decoded" "$officialApk"
    containerApktool "$workDir/built-decoded" "$workDir/built.apk"

    diff_output=$(diff -r "$workDir/official-decoded" "$workDir/built-decoded" 2>&1 | grep -v "META-INF" || true)
    total_diffs=$(echo "$diff_output" | grep -c "^" || echo "0")
    [[ -z "$diff_output" ]] && total_diffs=0
else
    # Split APK comparison using bundletool
    echo "Extracting splits from AAB using bundletool..."

    $CONTAINER_CMD run --rm \
        -v "$workDir":/work \
        docker.io/walletscrutiny/android:5 \
        sh -c "
            wget -q https://github.com/google/bundletool/releases/download/1.17.2/bundletool-all-1.17.2.jar -O /tmp/bundletool.jar
            java -jar /tmp/bundletool.jar build-apks \
                --bundle=/work/built.aab \
                --output=/work/built.apks \
                --device-spec=/work/device-spec.json \
                --mode=default
            mkdir -p /work/built-splits
            unzip -qq /work/built.apks -d /work/built-splits-raw
            cp /work/built-splits-raw/splits/*.apk /work/built-splits/ 2>/dev/null || true
        "

    # Decode and compare each split
    mkdir -p "$workDir/official-decoded" "$workDir/built-decoded"
    total_diffs=0

    for official in "$apkDir"/*.apk; do
        [[ -f "$official" ]] || continue
        name=$(basename "$official" .apk)

        # Normalize names
        if [[ "$name" == "base" ]]; then
            builtName="base-master"
        else
            builtName=$(echo "$name" | sed 's/split_config\./base-/')
        fi

        built="$workDir/built-splits/${builtName}.apk"
        [[ ! -f "$built" ]] && built="$workDir/built-splits/${name}.apk"

        if [[ ! -f "$built" ]]; then
            echo "  Warning: No match for $name"
            continue
        fi

        containerApktool "$workDir/official-decoded/$name" "$official"
        containerApktool "$workDir/built-decoded/$name" "$built"

        split_diff=$(diff -r "$workDir/official-decoded/$name" "$workDir/built-decoded/$name" 2>&1 | grep -v "META-INF" || true)
        if [[ -n "$split_diff" ]]; then
            count=$(echo "$split_diff" | grep -c "^" || echo "0")
            total_diffs=$((total_diffs + count))
            echo "$split_diff" > "$workDir/diff_${name}.txt"
            echo "  $name: $count differences"
        else
            echo "  $name: identical"
        fi
    done

    diff_output=$(cat "$workDir"/diff_*.txt 2>/dev/null || true)
fi

# Results
echo ""
echo "===== Verification Results ====="
echo "appId:          $appId"
echo "apkVersionName: $officialVersion"
echo "apkVersionCode: ${versionCode:-unknown}"
echo "appHash:        $appHash"
echo "signer:         ${signer:-unknown}"
echo "commit:         $commit"
echo ""

if [[ $total_diffs -eq 0 ]]; then
    verdict="reproducible"
    echo -e "verdict:        ${GREEN}$verdict${NC}"
    exitCode=0
else
    verdict="differences found"
    echo -e "verdict:        ${RED}$verdict${NC}"
    echo ""
    echo "Differences (excluding META-INF):"
    echo "$diff_output" | head -30
    [[ $(echo "$diff_output" | wc -l) -gt 30 ]] && echo "... (truncated, see $workDir/)"
    exitCode=1
fi

echo "===== End Results ====="

# Cleanup
if [[ "$shouldCleanup" == true ]]; then
    rm -rf "$workDir"
    echo "Workspace cleaned up"
else
    echo ""
    echo "Workspace: $workDir"
fi

exit $exitCode
