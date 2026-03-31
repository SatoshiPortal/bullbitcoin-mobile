# Flutter Debugger Scripts

**Role**: THE DEBUGGER
**Purpose**: Capture and analyze Flutter app debug logs

---

## Simple Logging Workflow

### 1. Start Log Capture
```bash
./debug-scripts/start-logging.sh
```

This will:
- Clear existing device logs
- Start capturing all logcat output to timestamped file
- Run in background while you test

### 2. Test App Flows
- Launch the app manually or use emulator
- Test different features and flows
- Reproduce any bugs or issues
- Logs are captured automatically

### 3. Stop Log Capture
```bash
./debug-scripts/stop-logging.sh
```

This will:
- Stop the background logging process
- Show log file location and size
- Prepare logs for analysis

### 4. Analyze Logs
```bash
./debug-scripts/analyze-logs.sh
```

This will:
- Parse the latest log file
- Extract errors, exceptions, crashes
- Count warnings by type
- Create structured analysis report with sections for your notes

Or analyze a specific log:
```bash
./debug-scripts/analyze-logs.sh 20260103_051229
```

---

## Output Files

```
debug-scripts/logs/
├── logcat-YYYYMMDD_HHMMSS.log     # Raw logcat output
└── analysis-YYYYMMDD_HHMMSS.md    # Structured analysis
```

---

## Quick Commands

**Check if logging is active:**
```bash
ps aux | grep "adb logcat"
```

**Watch logs live:**
```bash
tail -f debug-scripts/logs/logcat-*.log
```

**Filter for errors only:**
```bash
grep -E "ERROR|FATAL|Exception" debug-scripts/logs/logcat-*.log
```

**Filter for app-specific logs:**
```bash
grep -i "bullbitcoin\|bb_mobile" debug-scripts/logs/logcat-*.log
```

**Filter for Flutter logs:**
```bash
grep "flutter" debug-scripts/logs/logcat-*.log
```

---

## Analysis Report Sections

Each analysis report includes:

1. **Error Summary**
   - Fatal errors (FATAL/AndroidRuntime)
   - Exceptions
   - Flutter errors

2. **App-Specific Logs**
   - BullBitcoin/bb_mobile tagged entries

3. **Native Crashes**
   - Segfaults, signals, crashes

4. **Warnings**
   - All warning types with counts

5. **Notes Section** (for your analysis)
   - Root cause analysis
   - Files to investigate
   - Suggested fixes

---

## Debugger Workflow

```
┌─────────────────────────────────────────┐
│  1. start-logging.sh                    │
│     Start capturing all logs            │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  2. Test App                             │
│     - Open app on emulator               │
│     - Test different flows               │
│     - Reproduce issues                   │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  3. stop-logging.sh                      │
│     Stop capture, save logs              │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  4. analyze-logs.sh                      │
│     Generate analysis report             │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  5. Add Notes to Report                  │
│     - Root cause analysis                │
│     - File/line references               │
│     - Suggested fixes                    │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│  6. Share with Lead Engineer             │
└─────────────────────────────────────────┘
```

---

## Legacy Scripts

**run-debugger.sh** - Full automation (emulator + build + run)
Not recommended for testing - use the simple logging workflow above instead.

---

## Tips

- Start fresh logging for each testing session
- Keep logs focused on specific features/bugs
- Add detailed notes to analysis reports
- Include reproduction steps in notes
- Reference specific log line numbers when filing issues
