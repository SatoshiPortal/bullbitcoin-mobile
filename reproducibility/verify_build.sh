#!/bin/bash
# ==============================================================================
# Bull Bitcoin Mobile - Reproducible Build Verification Script
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Helper: Run apktool in container
containerApktool() {
    local targetFolder="$1"
    local app="$2"
    local targetFolderParent=$(dirname "$targetFolder")
    local targetFolderBase=$(basename "$targetFolder")
    local appFolder=$(dirname "$app")
    local appFile=$(basename "$app")

    $CONTAINER_CMD run --rm \
        -v "$targetFolderParent":/tfp \
        -v "$appFolder":/af:ro \
        $VERIFY_TOOLS_IMAGE \
        sh -c "apktool d -f -o /tfp/$targetFolderBase /af/$appFile"
}

# Helper: authoritative reproducibility verdict — hashes every zip entry's raw
# content (see compare_apk_entries.sh for why this, not the apktool diff
# below, is the thing that decides pass/fail).
containerCompareApks() {
    local apk1="$1" apk2="$2"
    local dir1=$(dirname "$apk1") file1=$(basename "$apk1")
    local dir2=$(dirname "$apk2") file2=$(basename "$apk2")

    $CONTAINER_CMD run --rm \
        -v "$dir1":/a:ro \
        -v "$dir2":/b:ro \
        -v "$SCRIPT_DIR/compare_apk_entries.sh":/compare.sh:ro \
        $VERIFY_TOOLS_IMAGE \
        sh /compare.sh "/a/$file1" "/b/$file2"
}

# apktool's decoded output normalizes away real byte-level differences
# (baksmali can re-emit different dex bytes as identical smali; aapt2 can
# decode different resources.arsc bytes to identical XML), so it is used only
# to explain *what* changed once containerCompareApks has already found a
# real difference — never as the verdict itself. The exclusion here mirrors
# compare_apk_entries.sh: only the legacy JAR signature files, anchored by
# name, not a blanket "META-INF" substring match (which would also hide
# tampering in META-INF/services/* ServiceLoader registrations and other
# real shipped content).
APKTOOL_DIFF_EXCLUDES=(-x "MANIFEST.MF" -x "*.RSA" -x "*.SF" -x "*.EC" -x "*.DSA")


usage() {
    cat <<'EOF'
Usage: verify_build.sh --version <version> [OPTIONS]

OPTIONS:
    --version <version>   App version to build (required, e.g., 10.9.8)
    --apk <path>          Path to official APK or directory with split APKs
                          If omitted: downloads universal APK from GitHub
                          If file: single APK comparison
                          If directory: split APK comparison (Play Store path)
    --cleanup             Remove workspace after completion
    --yes                 Skip interactive prompts (for CI/automation)
    --allow-dirty         Skip the working-tree cleanliness check (not recommended:
                          a dirty tree builds modified sources while this script
                          still attests the clean commit hash)
    --help                Show this help

EXAMPLES:
    # Verify against GitHub release
    ./verify_build.sh --version 10.9.8

    # Verify against Play Store (split APKs extracted from device)
    ./verify_build.sh --version 10.9.8 --apk ~/bullbitcoin-splits/

    # Verify against local APK file
    ./verify_build.sh --version 10.9.8 --apk ./official.apk
EOF
}

# Parse arguments
appVersion=""
apkPath=""
shouldCleanup=false
skipPrompts=false
allowDirty=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) appVersion="$2"; shift ;;
        --apk) apkPath="$2"; shift ;;
        --cleanup) shouldCleanup=true ;;
        --yes) skipPrompts=true ;;
        --allow-dirty) allowDirty=true ;;
        --help) usage; exit 0 ;;
        *) echo "Unknown argument: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ -z "$appVersion" && -z "$apkPath" ]]; then
    echo -e "${RED}Error: --version is required when --apk is not provided${NC}"
    usage
    exit 1
fi

if [[ -n "$appVersion" ]]; then
    expectedTag="v${appVersion}"
    localTag=$(git -C "$REPO_ROOT" tag --points-at HEAD 2>/dev/null | grep -x "$expectedTag" || true)
    if [[ -z "$localTag" ]]; then
        currentRef=$(git -C "$REPO_ROOT" describe --tags --always 2>/dev/null || echo "unknown")
        echo -e "${RED}Error: local repo is not at tag $expectedTag (currently at: $currentRef)${NC}"
        echo "Run: git checkout $expectedTag"
        exit 1
    fi
fi

# Containerfile.app does `COPY . /app`, and SOURCE_DATE_EPOCH plus the
# "commit:" line in RESULTS.md both come from `git log`, not from what's
# actually on disk. A dirty tree would silently build modified sources while
# this script still attests a clean commit hash. Modified/staged tracked
# files are a hard failure; untracked files only warn, since expected
# host-side byproducts (prior APKs, build caches) are untracked but already
# excluded from the build context via .dockerignore.
if [[ "$allowDirty" == false ]]; then
    if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
        echo -e "${RED}Error: working tree has uncommitted changes to tracked files.${NC}"
        echo "The build would embed these changes while attesting a clean commit hash."
        echo "Commit or stash them, or pass --allow-dirty to proceed anyway (not recommended)."
        git -C "$REPO_ROOT" status --short
        exit 1
    fi
    untrackedCount=$(git -C "$REPO_ROOT" ls-files --others --exclude-standard | wc -l | tr -d ' ')
    if [[ "$untrackedCount" -gt 0 ]]; then
        echo -e "${YELLOW}Warning: $untrackedCount untracked file(s) present in the repo. Verify none would be picked up by the build (check .dockerignore).${NC}"
    fi
fi

# Check required tools (not universally pre-installed on all Linux systems)
for tool in curl git; do
    if ! command -v "$tool" &> /dev/null; then
        echo -e "${RED}Error: $tool is not installed.${NC}"
        exit 1
    fi
done

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

# Build verification tools container
VERIFY_TOOLS_IMAGE="bullbitcoin-verify-tools:latest"
echo "Building verification tools container..."
$CONTAINER_CMD build -q -t "$VERIFY_TOOLS_IMAGE" "$SCRIPT_DIR" > /dev/null

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
    apkDir="$(cd "$apkPath" && pwd)"
    if [[ ! -f "$apkDir/base.apk" ]]; then
        echo -e "${RED}Error: base.apk not found in $apkDir${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: $apkPath not found${NC}"
    exit 1
fi

# Extract version from APK when --version not provided
if [[ -z "$appVersion" ]]; then
    tempDir=$(mktemp -d)
    containerApktool "$tempDir" "$apkDir/base.apk"
    appVersion=$(grep 'versionName' "$tempDir/apktool.yml" | awk '{print $2}' | tr -d "'")
    rm -rf "$tempDir"
    if [[ -z "$appVersion" ]]; then
        echo -e "${RED}Error: could not extract version from APK. Use --version to specify it.${NC}"
        exit 1
    fi
    echo "Version (from APK): $appVersion"
    expectedTag="v${appVersion}"
    localTag=$(git -C "$REPO_ROOT" tag --points-at HEAD 2>/dev/null | grep -x "$expectedTag" || true)
    if [[ -z "$localTag" ]]; then
        currentRef=$(git -C "$REPO_ROOT" describe --tags --always 2>/dev/null || echo "unknown")
        echo -e "${RED}Error: local repo is not at tag $expectedTag (currently at: $currentRef)${NC}"
        echo "Run: git checkout $expectedTag"
        exit 1
    fi
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

    echo "App ID: $appId"
    echo "Version: $officialVersion ($versionCode)"
    echo "Hash: $appHash"
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

    curl -sL "$apkUrl" -o "$workDir/official.apk"
    echo "Downloaded: $workDir/official.apk"

    # Extract metadata
    tempDir=$(mktemp -d)
    containerApktool "$tempDir" "$workDir/official.apk"
    officialVersion=$(grep 'versionName' "$tempDir/apktool.yml" | awk '{print $2}' | tr -d "'" || echo "$appVersion")
    versionCode=$(grep 'versionCode' "$tempDir/apktool.yml" | awk '{print $2}' | tr -d "'" || echo "unknown")
    rm -rf "$tempDir"

    appHash=$(sha256sum "$workDir/official.apk" | awk '{print $1}')
fi

# Memory probe is best-effort and platform-specific. `free` is Linux-only;
# on macOS/BSD derive total from sysctl (no cheap "available" metric, so use
# total as the proxy for the heap heuristic below). Unknown platforms skip the
# guard rather than abort under `set -e`.
if command -v free &> /dev/null; then
    available_mem_gb=$(free -g | awk '/^Mem:/ {print $7}')
    total_mem_gb=$(free -g | awk '/^Mem:/ {print $2}')
elif sysctl -n hw.memsize &> /dev/null; then
    total_mem_gb=$(( $(sysctl -n hw.memsize) / 1073741824 ))
    available_mem_gb=$total_mem_gb
else
    available_mem_gb=99
    total_mem_gb=99
fi
echo "Memory: ${available_mem_gb}GB available / ${total_mem_gb}GB total"
if [[ $available_mem_gb -lt 4 ]]; then
    echo -e "${YELLOW}Warning: Low memory. Build may fail.${NC}"
    if [[ "$skipPrompts" == false ]]; then
        read -p "Continue? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
fi

# Calculate Gradle heap based on available memory
if [[ $available_mem_gb -lt 6 ]]; then
    gradle_heap="2g"
elif [[ $available_mem_gb -lt 10 ]]; then
    gradle_heap="4g"
else
    gradle_heap="6g"
fi
echo "Gradle heap size: $gradle_heap (based on ${available_mem_gb}GB available)"

# Build using the same make targets as CI / local
echo "=== Building from source ==="
echo "This may take 30-60 minutes..."

buildFormat="apk"
[[ "$verificationMode" == "device" ]] && buildFormat="aab"

cd "$REPO_ROOT"
GRADLE_HEAP="$gradle_heap" FORMAT="$buildFormat" CONTAINER="$CONTAINER_CMD" make android release
cd - > /dev/null

if [[ "$verificationMode" == "github" ]]; then
    cp "$REPO_ROOT/BULL-release.apk" "$workDir/built.apk"
else
    cp "$REPO_ROOT/BULL-release.aab" "$workDir/built.aab"
fi

echo "Build complete"

commit=$(git -C "$REPO_ROOT" rev-parse HEAD)
echo "Built from commit: $commit"

# Compare
echo ""
echo "=== Comparing builds ==="

if [[ "$verificationMode" == "github" ]]; then
    # Direct APK comparison
    officialApk="$workDir/official.apk"
    [[ -f "$apkDir/base.apk" ]] && officialApk="$apkDir/base.apk"

    # Authoritative verdict: raw per-entry content hash comparison.
    if rawCompareOutput=$(containerCompareApks "$officialApk" "$workDir/built.apk" 2>&1); then
        total_diffs=0
    else
        total_diffs=1
        echo "$rawCompareOutput" > "$workDir/raw_entry_diff.txt"
    fi

    # apktool decode kept purely as a diagnostic to explain *what* differs —
    # see the comment on containerCompareApks above for why it isn't the verdict.
    mkdir -p "$workDir/official-decoded" "$workDir/built-decoded"
    containerApktool "$workDir/official-decoded" "$officialApk"
    containerApktool "$workDir/built-decoded" "$workDir/built.apk"

    diff_output=$(diff -r "${APKTOOL_DIFF_EXCLUDES[@]}" "$workDir/official-decoded" "$workDir/built-decoded" 2>&1 || true)
    [[ -n "$diff_output" ]] && echo "$diff_output" > "$workDir/diff.txt"
else
    # Split APK comparison using bundletool
    echo "Extracting splits from AAB using bundletool..."

    $CONTAINER_CMD run --rm \
        -v "$workDir":/work \
        $VERIFY_TOOLS_IMAGE \
        sh -c "
            bundletool build-apks \
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
    # Newline-delimited (not a bash array) so this stays portable to the
    # older bash shipped by default on macOS, where `set -u` + empty arrays
    # is a known footgun.
    matchedBuiltNames=""

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
        if [[ ! -f "$built" ]]; then
            built="$workDir/built-splits/${name}.apk"
            builtName="$name"
        fi

        # A missing built counterpart used to be a skipped warning that still
        # exited 0 — an entire split (potentially all native libs, or all
        # drawables) could go completely unverified with a clean PASS. Treat
        # it as a hard failure instead.
        if [[ ! -f "$built" ]]; then
            echo -e "${RED}  ✗ $name: no matching built split found (expected ${builtName}.apk) — FAIL${NC}"
            total_diffs=$((total_diffs + 1))
            continue
        fi
        matchedBuiltNames="$matchedBuiltNames
$(basename "$built")"

        if rawCompareOutput=$(containerCompareApks "$official" "$built" 2>&1); then
            echo "  $name: identical"
        else
            total_diffs=$((total_diffs + 1))
            echo -e "${RED}  $name: differences found${NC}"
            echo "$rawCompareOutput" > "$workDir/raw_entry_diff_${name}.txt"
        fi

        containerApktool "$workDir/official-decoded/$name" "$official"
        containerApktool "$workDir/built-decoded/$name" "$built"
        split_diff=$(diff -r "${APKTOOL_DIFF_EXCLUDES[@]}" "$workDir/official-decoded/$name" "$workDir/built-decoded/$name" 2>&1 || true)
        [[ -n "$split_diff" ]] && echo "$split_diff" > "$workDir/diff_${name}.txt"
    done

    # The reverse direction matters too: a built split with no official
    # counterpart (e.g. bundletool's split-generation diverging from the
    # official device-spec mapping) previously wasn't even enumerated, so it
    # went unverified with no warning at all.
    for built in "$workDir"/built-splits/*.apk; do
        [[ -f "$built" ]] || continue
        bname=$(basename "$built")
        if ! grep -qxF "$bname" <<< "$matchedBuiltNames"; then
            echo -e "${RED}  ✗ $bname: built split has no official counterpart — FAIL${NC}"
            total_diffs=$((total_diffs + 1))
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
    echo "Verdict is based on a raw per-entry content hash comparison (see raw_entry_diff*.txt in $workDir/)."
    echo "The apktool-decoded diff below (excluding legacy JAR signature files only) is a diagnostic aid, not the verdict:"
    { echo "$diff_output" | head -30; } || true
    [[ $(echo "$diff_output" | wc -l) -gt 30 ]] && echo "... (truncated, see $workDir/)"
    exitCode=1
fi

echo "===== End Results ====="

# Write results to file
cat > "$workDir/RESULTS.md" <<EOF
# Bull Bitcoin Mobile - Verification Results

| Field          | Value |
|----------------|-------|
| date           | $(date -u +"%Y-%m-%dT%H:%M:%SZ") |
| appId          | $appId |
| versionName    | $officialVersion |
| versionCode    | ${versionCode:-unknown} |
| appHash        | $appHash |
| commit         | $commit |
| verdict        | $verdict |
EOF

if [[ $total_diffs -gt 0 ]]; then
    echo "" >> "$workDir/RESULTS.md"
    echo "## Raw entry-hash differences (authoritative verdict)" >> "$workDir/RESULTS.md"
    echo "" >> "$workDir/RESULTS.md"
    echo "\`\`\`" >> "$workDir/RESULTS.md"
    cat "$workDir"/raw_entry_diff*.txt >> "$workDir/RESULTS.md" 2>/dev/null || echo "(no raw entry diff file — see split-matching failures logged above)" >> "$workDir/RESULTS.md"
    echo "\`\`\`" >> "$workDir/RESULTS.md"

    echo "" >> "$workDir/RESULTS.md"
    echo "## apktool-decoded diff (diagnostic only — excludes legacy JAR signature files, not the verdict)" >> "$workDir/RESULTS.md"
    echo "" >> "$workDir/RESULTS.md"
    echo "\`\`\`" >> "$workDir/RESULTS.md"
    cat "$workDir"/diff*.txt >> "$workDir/RESULTS.md" 2>/dev/null || true
    echo "\`\`\`" >> "$workDir/RESULTS.md"
fi

# Cleanup
if [[ "$shouldCleanup" == true ]]; then
    rm -rf "$workDir"
    echo "Workspace cleaned up"
else
    echo ""
    echo "Workspace: $workDir"
fi

exit $exitCode
