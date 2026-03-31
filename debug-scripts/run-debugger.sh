#!/bin/bash

# Bull Bitcoin Mobile - Flutter Debugger Script
# Role: THE DEBUGGER
# Purpose: Launch emulator, run Flutter debug, monitor logs, and track errors

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
EMULATOR_NAME="Pixel_7"
PROJECT_ROOT="/home/ishi/operator/dev/wallet/repo/bullbitcoin-mobile"
DEBUG_LOGS_DIR="$PROJECT_ROOT/debug-scripts/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ERROR_REPORT="$DEBUG_LOGS_DIR/error-report-$TIMESTAMP.md"
FLUTTER_LOG="$DEBUG_LOGS_DIR/flutter-debug-$TIMESTAMP.log"

# Create logs directory
mkdir -p "$DEBUG_LOGS_DIR"

# Header
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Bull Bitcoin Mobile - Debugger${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "Emulator: ${GREEN}$EMULATOR_NAME${NC}"
echo -e "Error Report: ${BLUE}$ERROR_REPORT${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Initialize error report
cat > "$ERROR_REPORT" <<EOF
# Flutter Debug Error Report
**Generated**: $(date '+%Y-%m-%d %H:%M:%S')
**Emulator**: $EMULATOR_NAME
**Project**: Bull Bitcoin Mobile

---

## Session Overview

**Status**: 🔄 In Progress
**Build Status**: Pending
**Runtime Status**: Pending

---

## Build Errors

EOF

# Function to check if emulator is running
check_emulator() {
    if adb devices | grep -q "emulator"; then
        return 0
    else
        return 1
    fi
}

# Function to wait for emulator boot
wait_for_emulator() {
    echo -e "${YELLOW}⏳ Waiting for emulator to boot...${NC}"
    local timeout=120
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        if adb shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; then
            echo -e "${GREEN}✓ Emulator booted successfully${NC}\n"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -ne "\r${YELLOW}⏳ Waiting... ${elapsed}s${NC}"
    done

    echo -e "\n${RED}✗ Emulator boot timeout${NC}"
    return 1
}

# Function to append to error report
log_error() {
    local error_type="$1"
    local error_msg="$2"
    local file_ref="$3"
    local line_num="$4"

    cat >> "$ERROR_REPORT" <<EOF

### $error_type

**Error**: $error_msg
$([ -n "$file_ref" ] && echo "**File**: \`$file_ref$([ -n "$line_num" ] && echo ":$line_num")\`")
**Timestamp**: $(date '+%H:%M:%S')

**Analysis**:
-

**Suggested Fix**:
-

---
EOF
}

# Step 1: Check if emulator is already running
echo -e "${BLUE}► Step 1: Checking emulator status...${NC}"
if check_emulator; then
    echo -e "${GREEN}✓ Emulator already running${NC}\n"
else
    echo -e "${YELLOW}⚠ Emulator not running. Starting $EMULATOR_NAME...${NC}"

    # Start emulator in background
    emulator -avd "$EMULATOR_NAME" -no-snapshot-save > /dev/null 2>&1 &
    EMULATOR_PID=$!
    echo -e "${GREEN}✓ Emulator started (PID: $EMULATOR_PID)${NC}"

    # Wait for boot
    if ! wait_for_emulator; then
        echo -e "${RED}✗ Failed to start emulator${NC}"
        log_error "Emulator Boot Failure" "Emulator failed to boot within timeout period" "" ""
        exit 1
    fi
fi

# Step 2: Navigate to project
echo -e "${BLUE}► Step 2: Navigating to project directory...${NC}"
cd "$PROJECT_ROOT"
echo -e "${GREEN}✓ In project directory${NC}\n"

# Step 3: Get device ID
echo -e "${BLUE}► Step 3: Detecting device...${NC}"
DEVICE_ID=$(flutter devices | grep emulator | grep -o 'emulator-[0-9]*' | head -1)
if [ -z "$DEVICE_ID" ]; then
    echo -e "${RED}✗ No emulator device found${NC}"
    log_error "Device Detection Failure" "Flutter could not detect emulator device" "" ""
    exit 1
fi
echo -e "${GREEN}✓ Device detected: $DEVICE_ID${NC}\n"

# Step 4: Run Flutter Debug
echo -e "${BLUE}► Step 4: Launching Flutter Debug...${NC}"
echo -e "${CYAN}---------------------------------------------------${NC}"
echo -e "${YELLOW}📱 Flutter Debug Output (monitoring for errors)${NC}"
echo -e "${CYAN}---------------------------------------------------${NC}\n"

# Run flutter in background and capture output
flutter run -d "$DEVICE_ID" --verbose 2>&1 | tee "$FLUTTER_LOG" | while IFS= read -r line; do
    # Print line
    echo "$line"

    # Check for build errors
    if echo "$line" | grep -qi "error\|exception\|failed"; then
        if echo "$line" | grep -q "Gradle task"; then
            log_error "Build Error - Gradle" "$(echo $line | sed 's/\x1b\[[0-9;]*m//g')" "" ""
        elif echo "$line" | grep -q "Dart"; then
            log_error "Build Error - Dart" "$(echo $line | sed 's/\x1b\[[0-9;]*m//g')" "" ""
        else
            log_error "Build Error" "$(echo $line | sed 's/\x1b\[[0-9;]*m//g')" "" ""
        fi
    fi

    # Check for runtime errors
    if echo "$line" | grep -qi "flutter.*error"; then
        log_error "Runtime Error - Flutter" "$(echo $line | sed 's/\x1b\[[0-9;]*m//g')" "" ""
    fi

    # Check for native crashes
    if echo "$line" | grep -qi "fatal.*exception\|segfault\|crashed"; then
        log_error "Native Crash" "$(echo $line | sed 's/\x1b\[[0-9;]*m//g')" "" ""
    fi
done

# Update final status in error report
sed -i 's/Status\*\*: 🔄 In Progress/Status**: ✅ Completed/' "$ERROR_REPORT"

echo -e "\n${CYAN}========================================${NC}"
echo -e "${GREEN}✓ Debug session completed${NC}"
echo -e "${BLUE}📄 Error report: $ERROR_REPORT${NC}"
echo -e "${BLUE}📋 Full log: $FLUTTER_LOG${NC}"
echo -e "${CYAN}========================================${NC}"
