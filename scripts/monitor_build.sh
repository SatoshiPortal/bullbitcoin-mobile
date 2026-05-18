#!/bin/bash
# Monitors disk space and build processes every 30s
# Kills build if disk drops below 10GB
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG="/tmp/build_monitor.log"
echo "Build monitor started at $(date)" > "$LOG"

trap 'echo "Monitor stopped at $(date)" >> "$LOG"; exit' INT TERM

while true; do
    FREE_KB=$(df -k / | tail -1 | awk '{print $4}')
    FREE_GB=$((FREE_KB / 1024 / 1024))
    RUST=$(ps aux | grep "rustc\|cargo" | grep -v grep | wc -l | tr -d ' ')
    GRADLE=$(ps aux | grep "gradle\|kotlin\|d8" | grep -v grep | wc -l | tr -d ' ')
    APK=$(find "$SCRIPT_DIR/build" -name "*.apk" 2>/dev/null | head -1)
    BUILD_SIZE=$(du -sm "$SCRIPT_DIR/build" 2>/dev/null | awk '{print $1}')

    TIMESTAMP=$(date +%H:%M:%S)
    MSG="[$TIMESTAMP] Free: ${FREE_GB}GB | Build: ${BUILD_SIZE:-0}MB | Rust: $RUST | Gradle: $GRADLE"

    if [ -n "$APK" ]; then
        MSG="$MSG | APK: FOUND!"
        echo "$MSG" >> "$LOG"
        echo "$MSG"
        echo "BUILD COMPLETE" >> "$LOG"
        break
    fi

    if [ "$FREE_GB" -lt 10 ]; then
        MSG="$MSG | DANGER: <10GB free, killing build!"
        echo "$MSG" >> "$LOG"
        echo "$MSG"
        pkill -f "GradleDaemon" 2>/dev/null
        pkill -f "KotlinCompileDaemon" 2>/dev/null
        pkill -f "cargo build" 2>/dev/null
        pkill -f "rustc" 2>/dev/null
        echo "BUILD KILLED - DISK TOO LOW" >> "$LOG"
        exit 1
    fi

    if [ "$RUST" -eq 0 ] && [ "$GRADLE" -eq 0 ]; then
        MSG="$MSG | No build processes found"
        echo "$MSG" >> "$LOG"
        echo "$MSG"
        echo "BUILD ENDED (no processes)" >> "$LOG"
        break
    fi

    echo "$MSG" >> "$LOG"
    echo "$MSG"
    sleep 30
done
