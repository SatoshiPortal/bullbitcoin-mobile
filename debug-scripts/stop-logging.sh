#!/bin/bash

# Bull Bitcoin Mobile - Stop Debug Logging

set -e

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="/home/ishi/operator/dev/wallet/repo/bullbitcoin-mobile"
LOGS_DIR="$PROJECT_ROOT/debug-scripts/logs"
PID_FILE="$LOGS_DIR/.logging.pid"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Stopping Debug Logging${NC}"
echo -e "${CYAN}========================================${NC}"

# Check if logging is running
if [ ! -f "$PID_FILE" ]; then
    echo -e "${RED}✗ No logging session found${NC}"
    exit 1
fi

# Read PID and timestamp
LOGGING_PID=$(head -1 "$PID_FILE")
TIMESTAMP=$(tail -1 "$PID_FILE")
LOG_FILE="$LOGS_DIR/logcat-$TIMESTAMP.log"

# Stop the process
if ps -p $LOGGING_PID > /dev/null 2>&1; then
    kill $LOGGING_PID
    echo -e "${GREEN}✓ Logging stopped (PID: $LOGGING_PID)${NC}"
else
    echo -e "${YELLOW}⚠ Process already stopped${NC}"
fi

# Remove PID file
rm "$PID_FILE"

# Show log info
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(du -h "$LOG_FILE" | cut -f1)
    LOG_LINES=$(wc -l < "$LOG_FILE")
    echo -e "${GREEN}✓ Log saved: $LOG_FILE${NC}"
    echo -e "${GREEN}  Size: $LOG_SIZE, Lines: $LOG_LINES${NC}"
else
    echo -e "${RED}✗ Log file not found${NC}"
fi

echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "📊 Analyze with: ${YELLOW}./debug-scripts/analyze-logs.sh $TIMESTAMP${NC}"
echo ""
