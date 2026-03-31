#!/bin/bash

# Bull Bitcoin Mobile - Start Debug Logging
# Captures all Android logcat output to timestamped file

set -e

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="/home/ishi/operator/dev/wallet/repo/bullbitcoin-mobile"
LOGS_DIR="$PROJECT_ROOT/debug-scripts/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOGS_DIR/logcat-$TIMESTAMP.log"
PID_FILE="$LOGS_DIR/.logging.pid"

# Create logs directory
mkdir -p "$LOGS_DIR"

# Check if already logging
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p $OLD_PID > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Logging already running (PID: $OLD_PID)${NC}"
        echo -e "${YELLOW}  Stop it first with: ./debug-scripts/stop-logging.sh${NC}"
        exit 1
    else
        rm "$PID_FILE"
    fi
fi

# Clear existing logs on device
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Bull Bitcoin - Debug Logging${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${YELLOW}⏳ Clearing device logs...${NC}"
adb logcat -c 2>/dev/null || echo "No device connected"

# Start logging in background
echo -e "${YELLOW}⏳ Starting log capture...${NC}"
adb logcat -v time > "$LOG_FILE" 2>&1 &
LOGGING_PID=$!

# Save PID
echo $LOGGING_PID > "$PID_FILE"
echo $TIMESTAMP >> "$PID_FILE"

echo -e "${GREEN}✓ Logging started (PID: $LOGGING_PID)${NC}"
echo -e "${GREEN}✓ Output: $LOG_FILE${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "📝 Logs are being captured..."
echo -e "🧪 Now test the app flows"
echo -e "🛑 Stop with: ${YELLOW}./debug-scripts/stop-logging.sh${NC}"
echo -e "👁  Watch live: ${YELLOW}tail -f $LOG_FILE${NC}"
echo ""
