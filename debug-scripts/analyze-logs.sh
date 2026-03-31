#!/bin/bash

# Bull Bitcoin Mobile - Analyze Debug Logs
# Filters and summarizes captured logs

set -e

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="/home/ishi/operator/dev/wallet/repo/bullbitcoin-mobile"
LOGS_DIR="$PROJECT_ROOT/debug-scripts/logs"

# Get timestamp parameter or use latest
if [ -n "$1" ]; then
    TIMESTAMP="$1"
    LOG_FILE="$LOGS_DIR/logcat-$TIMESTAMP.log"
else
    LOG_FILE=$(ls -t $LOGS_DIR/logcat-*.log 2>/dev/null | head -1)
    if [ -z "$LOG_FILE" ]; then
        echo -e "${RED}✗ No log files found${NC}"
        exit 1
    fi
    TIMESTAMP=$(basename "$LOG_FILE" | sed 's/logcat-\(.*\)\.log/\1/')
fi

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}✗ Log file not found: $LOG_FILE${NC}"
    exit 1
fi

ANALYSIS_FILE="$LOGS_DIR/analysis-$TIMESTAMP.md"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Log Analysis${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "Log file: ${GREEN}$LOG_FILE${NC}"
echo -e "Analysis: ${GREEN}$ANALYSIS_FILE${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Create analysis report
cat > "$ANALYSIS_FILE" <<EOF
# Bull Bitcoin Mobile - Log Analysis
**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Log File**: \`$(basename $LOG_FILE)\`
**Log Timestamp**: $TIMESTAMP

---

## Summary

**Total Lines**: $(wc -l < "$LOG_FILE")
**File Size**: $(du -h "$LOG_FILE" | cut -f1)

---

## Error Summary

### Fatal Errors
\`\`\`
$(grep -i "FATAL\|AndroidRuntime" "$LOG_FILE" | wc -l) fatal errors found
\`\`\`

$(grep -i "FATAL\|AndroidRuntime" "$LOG_FILE" | head -20)

### Exceptions
\`\`\`
$(grep -i "Exception" "$LOG_FILE" | grep -v "NoSuchMethodException" | wc -l) exceptions found
\`\`\`

$(grep -i "Exception" "$LOG_FILE" | grep -v "NoSuchMethodException" | head -20)

### Flutter Errors
\`\`\`
$(grep -i "flutter.*error\|F/flutter" "$LOG_FILE" | wc -l) Flutter errors found
\`\`\`

$(grep -i "flutter.*error\|F/flutter" "$LOG_FILE" | head -20)

---

## App-Specific Logs

### BullBitcoin App Logs
\`\`\`
$(grep -i "bullbitcoin\|bb_mobile" "$LOG_FILE" | wc -l) app-specific log entries
\`\`\`

$(grep -i "bullbitcoin\|bb_mobile" "$LOG_FILE" | head -30)

---

## Native Crashes

\`\`\`
$(grep -i "crash\|segfault\|signal " "$LOG_FILE" | wc -l) potential crashes
\`\`\`

$(grep -i "crash\|segfault\|signal " "$LOG_FILE" | head -20)

---

## Warnings

\`\`\`
$(grep " W/" "$LOG_FILE" | wc -l) warnings found
\`\`\`

Top 10 warning types:
$(grep " W/" "$LOG_FILE" | awk -F'[(/]' '{print $3}' | sort | uniq -c | sort -rn | head -10)

---

## Notes

### Root Cause Analysis
-

### Files to Investigate
-

### Suggested Fixes
-

---

EOF

echo -e "${GREEN}✓ Analysis complete${NC}\n"
echo -e "${CYAN}========================================${NC}"
echo -e "${YELLOW}Quick Stats:${NC}"
echo -e "  Fatal errors: ${RED}$(grep -i "FATAL\|AndroidRuntime" "$LOG_FILE" | wc -l)${NC}"
echo -e "  Exceptions: ${YELLOW}$(grep -i "Exception" "$LOG_FILE" | grep -v "NoSuchMethodException" | wc -l)${NC}"
echo -e "  Flutter errors: ${YELLOW}$(grep -i "flutter.*error\|F/flutter" "$LOG_FILE" | wc -l)${NC}"
echo -e "  Warnings: ${YELLOW}$(grep " W/" "$LOG_FILE" | wc -l)${NC}"
echo -e "${CYAN}========================================${NC}\n"

echo -e "📄 Full analysis: ${YELLOW}$ANALYSIS_FILE${NC}"
echo -e "🔍 View: ${YELLOW}cat $ANALYSIS_FILE${NC}"
echo ""
