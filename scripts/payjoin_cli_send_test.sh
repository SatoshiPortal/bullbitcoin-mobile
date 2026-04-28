#!/usr/bin/env bash
# Orchestrates the payjoin-cli sender <-> mobile receiver integration test.
#
# Steps:
#   1. Start the Flutter integration test — it creates a mobile receiver,
#      prints the BIP21 pjURI to stdout, then polls the directory for the
#      CLI's original PSBT.
#   2. Wait for that URI to appear in the test output.
#   3. Run payjoin-cli `send <bip21>` — it builds a PSBT and posts it.
#   4. The Flutter test picks up the request, processes it, creates a proposal,
#      and sends it back via the directory.  payjoin-cli picks it up and broadcasts.
#   5. Clean up on exit.
#
# Required env / .env variables:
#   PAYJOIN_CLI_SOURCE_DIR   Path to the payjoin-cli Cargo crate
#   PAYJOIN_CLI_RPCHOST      bitcoind RPC URL  (e.g. http://localhost:18332/wallet/test)
#   PAYJOIN_CLI_COOKIE_FILE  Path to bitcoind .cookie  — OR use RPCUSER + RPCPASSWORD
#   PAYJOIN_CLI_RPCUSER
#   PAYJOIN_CLI_RPCPASSWORD
#   TEST_ALICE_MNEMONIC      Mobile wallet mnemonic (needs testnet3 tBTC)
#
# Optional:
#   CARGO_PATH               Full path to cargo binary (default: cargo)
#   PAYJOIN_CLI_OHTTP_RELAY  OHTTP relay URL
#   PAYJOIN_CLI_PJ_DIRECTORY Payjoin directory URL
#   PAYJOIN_CLI_SEND_AMOUNT_SAT  Amount in sat for the mobile to receive (default: 2000)
#   PAYJOIN_CLI_FEE_RATE     Fee rate in sat/vB for payjoin-cli send (default: 2)
#   BIP21_WAIT_SECS          Seconds to wait for BIP21 URI from mobile (default: 180)

# NOTE: We intentionally do NOT use `set -e`. Errors are handled explicitly so
# that we always reach the results section and print clear PASS/FAIL output.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env from repo root
if [ -f "$REPO_DIR/.env" ]; then
  set -o allexport
  # shellcheck disable=SC1091
  source "$REPO_DIR/.env"
  set +o allexport
fi

# --- Config ---
CARGO_PATH="${CARGO_PATH:-cargo}"
RUST_TOOLCHAIN="${PAYJOIN_CLI_RUST_TOOLCHAIN:-1.85.0}"
CLI_SOURCE_DIR="${PAYJOIN_CLI_SOURCE_DIR:?PAYJOIN_CLI_SOURCE_DIR must be set}"
RPCHOST="${PAYJOIN_CLI_RPCHOST:?PAYJOIN_CLI_RPCHOST must be set}"
OHTTP_RELAY="${PAYJOIN_CLI_OHTTP_RELAY:-https://pj.benalleng.com}"
PJ_DIRECTORY="${PAYJOIN_CLI_PJ_DIRECTORY:-https://payjo.in}"
AMOUNT_SAT="${PAYJOIN_CLI_SEND_AMOUNT_SAT:-2000}"
FEE_RATE="${PAYJOIN_CLI_FEE_RATE:-2}"
BIP21_WAIT_SECS="${BIP21_WAIT_SECS:-180}"
CLI_TIMEOUT_SECS="${CLI_TIMEOUT_SECS:-300}"
CLI_BROADCAST_GRACE_SECS="${CLI_BROADCAST_GRACE_SECS:-60}"

# Pin the Rust toolchain for payjoin-cli builds
export RUSTUP_TOOLCHAIN="$RUST_TOOLCHAIN"

# --- Print Rust version ---
echo "[script] Using cargo: $CARGO_PATH (toolchain: $RUST_TOOLCHAIN)"
"$CARGO_PATH" --version
rustc --version

# --- Temp files ---
TMPDIR_WORK="$(mktemp -d)"
DB_PATH="$CLI_SOURCE_DIR/payjoin-test/payjoin.sqlite"
CLI_LOG="$TMPDIR_WORK/cli.log"
FLUTTER_LOG="$TMPDIR_WORK/flutter.log"
FLUTTER_PID=""
CLI_PID=""

echo "[script] Logs: $TMPDIR_WORK"

cleanup() {
  local exit_code=$?
  if [ -n "$FLUTTER_PID" ]; then
    echo "[cleanup] Killing Flutter test (PID $FLUTTER_PID)..."
    kill "$FLUTTER_PID" 2>/dev/null || true
  fi
  if [ -n "$CLI_PID" ]; then
    echo "[cleanup] Killing payjoin-cli (PID $CLI_PID)..."
    kill "$CLI_PID" 2>/dev/null || true
  fi
  # Stop the app on the device/emulator
  adb -s "${DEVICE_ID:-emulator-5554}" shell am force-stop com.bullbitcoin.mobile 2>/dev/null || true

  echo ""
  echo "========================================"
  echo "  LOGS"
  echo "========================================"
  echo "--- Flutter test output ---"
  cat "$FLUTTER_LOG" 2>/dev/null || echo "(empty)"
  echo ""
  echo "--- payjoin-cli output ---"
  cat "$CLI_LOG" 2>/dev/null || echo "(empty)"
  echo "========================================"
  echo ""

  if [ "$exit_code" -ne 0 ]; then
    echo "[cleanup] Preserving logs in $TMPDIR_WORK for inspection"
  else
    rm -rf "$TMPDIR_WORK"
  fi
}
trap cleanup EXIT

# --- Build RPC args ---
RPC_ARGS=(--rpchost "$RPCHOST")
COOKIE_FILE="${PAYJOIN_CLI_COOKIE_FILE:-}"
if [ -n "$COOKIE_FILE" ]; then
  RPC_ARGS+=(--cookie-file "$COOKIE_FILE")
else
  RPC_ARGS+=(
    --rpcuser "${PAYJOIN_CLI_RPCUSER:?PAYJOIN_CLI_RPCUSER or PAYJOIN_CLI_COOKIE_FILE must be set}"
    --rpcpassword "${PAYJOIN_CLI_RPCPASSWORD:?PAYJOIN_CLI_RPCPASSWORD must be set}"
  )
fi

# --- Find Android device ---
cd "$REPO_DIR"
DEVICE_ID="${ANDROID_DEVICE_ID:-$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')}"
if [ -z "$DEVICE_ID" ]; then
  echo "[script] ERROR: No Android device/emulator found. Start an emulator and retry."
  exit 1
fi
echo "[script] Using device: $DEVICE_ID"

# --- Start Flutter integration test in background ---
echo "[script] Starting Flutter integration test (mobile receiver)..."
fvm flutter test \
  --device-id="$DEVICE_ID" \
  --dart-define="PAYJOIN_CLI_SEND_AMOUNT_SAT=$AMOUNT_SAT" \
  integration_test/payjoin_cli_send_integration_test.dart \
  --reporter=compact \
  > "$FLUTTER_LOG" 2>&1 &
FLUTTER_PID=$!
echo "[script] Flutter PID: $FLUTTER_PID"

# --- Wait for BIP21 URI from Flutter test ---
echo "[script] Waiting up to ${BIP21_WAIT_SECS}s for mobile receiver BIP21 URI..."
BIP21_URI=""
for _ in $(seq 1 "$BIP21_WAIT_SECS"); do
  if grep -qm1 "PJ_URI:" "$FLUTTER_LOG" 2>/dev/null; then
    # The compact reporter may wrap long lines. Collapse continuations and
    # extract the full URI. Only match characters valid in a BIP21 URI
    # (letters, digits, and the set: % + ? & = : / . @ _ # -) so we stop
    # cleanly when the next log line (e.g. "[integration]") begins.
    BIP21_URI="$(tr -d '\r\n' < "$FLUTTER_LOG" | grep -oP 'PJ_URI:\Kbitcoin:[A-Za-z0-9%+?&=:/.@_#-]+' || true)"
    # Fallback: try simpler extraction if perl-style grep not available
    if [ -z "$BIP21_URI" ]; then
      BIP21_URI="$(tr -d '\r\n' < "$FLUTTER_LOG" | sed -n 's/.*PJ_URI:\(bitcoin:[A-Za-z0-9%+?&=:\/.@_#-]*\).*/\1/p')"
    fi
    break
  fi
  # Exit early if the Flutter test died
  if ! kill -0 "$FLUTTER_PID" 2>/dev/null; then
    echo "[script] ERROR: Flutter test exited before printing a BIP21 URI."
    exit 1
  fi
  sleep 1
done

if [ -z "$BIP21_URI" ]; then
  echo "[script] ERROR: Flutter test did not print a BIP21 URI within ${BIP21_WAIT_SECS}s."
  exit 1
fi

echo "[script] Extracted BIP21 URI (${#BIP21_URI} chars):"
echo "  $BIP21_URI"

# --- Append amount to URI if missing (payjoin-cli send requires it) ---
if [[ "$BIP21_URI" != *"amount="* ]]; then
  AMOUNT_BTC="$(awk -v sat="$AMOUNT_SAT" 'BEGIN { printf "%.8f", sat / 100000000 }')"
  if [ -z "$AMOUNT_BTC" ] || [ "$AMOUNT_BTC" = "0.00000000" ]; then
    echo "[script] ERROR: Failed to compute BTC amount from ${AMOUNT_SAT} sat (got: '${AMOUNT_BTC}')"
    exit 1
  fi
  BIP21_URI="${BIP21_URI}&amount=${AMOUNT_BTC}"
  echo "[script] Appended amount=${AMOUNT_BTC} BTC (${AMOUNT_SAT} sat) to URI"
fi

echo "[script] Final URI: $BIP21_URI"

# --- Run payjoin-cli send ---
echo "[script] Starting payjoin-cli send (fee-rate: ${FEE_RATE} sat/vB)..."
echo "[script] Full command: cargo run --manifest-path $CLI_SOURCE_DIR/Cargo.toml -- ${RPC_ARGS[*]} --db-path $DB_PATH --ohttp-relays $OHTTP_RELAY --pj-directory $PJ_DIRECTORY send --fee-rate $FEE_RATE \"$BIP21_URI\""

RUST_LOG=trace "$CARGO_PATH" run \
  --manifest-path "$CLI_SOURCE_DIR/Cargo.toml" \
  -- \
  "${RPC_ARGS[@]}" \
  --db-path "$DB_PATH" \
  --ohttp-relays "$OHTTP_RELAY" \
  --pj-directory "$PJ_DIRECTORY" \
  send --fee-rate "$FEE_RATE" "$BIP21_URI" \
  > "$CLI_LOG" 2>&1 &
CLI_PID=$!
echo "[script] payjoin-cli PID: $CLI_PID"

# --- Wait for both processes to finish ---
echo "[script] Waiting up to ${CLI_TIMEOUT_SECS}s for both processes..."

ELAPSED=0
FLUTTER_DONE=false
CLI_DONE=false
FLUTTER_EXIT=""
CLI_EXIT=""

while [ "$ELAPSED" -lt "$CLI_TIMEOUT_SECS" ]; do
  if [ "$FLUTTER_DONE" = false ] && ! kill -0 "$FLUTTER_PID" 2>/dev/null; then
    wait "$FLUTTER_PID" 2>/dev/null
    FLUTTER_EXIT=$?
    FLUTTER_DONE=true
    FLUTTER_PID=""
    echo "[script] Flutter test exited with code $FLUTTER_EXIT (${ELAPSED}s elapsed)"
  fi
  if [ "$CLI_DONE" = false ] && ! kill -0 "$CLI_PID" 2>/dev/null; then
    wait "$CLI_PID" 2>/dev/null
    CLI_EXIT=$?
    CLI_DONE=true
    CLI_PID=""
    echo "[script] payjoin-cli exited with code $CLI_EXIT (${ELAPSED}s elapsed)"
    # If the CLI exits before the Flutter test, the receiver has no sender to
    # interact with — kill Flutter immediately instead of waiting for its timeout.
    if [ "$FLUTTER_DONE" = false ]; then
      echo "[script] CLI exited early — killing Flutter test (no point waiting)."
      kill "$FLUTTER_PID" 2>/dev/null || true
      FLUTTER_PID=""
      FLUTTER_EXIT="killed"
      FLUTTER_DONE=true
    fi
  fi

  # Print periodic status while waiting
  if [ $((ELAPSED % 30)) -eq 0 ] && [ "$ELAPSED" -gt 0 ]; then
    echo -n "[script] Still waiting (${ELAPSED}s):"
    [ "$FLUTTER_DONE" = false ] && echo -n " flutter" || true
    [ "$CLI_DONE" = false ] && echo -n " cli" || true
    echo ""
    # Tail the CLI log to show progress
    if [ "$CLI_DONE" = false ] && [ -s "$CLI_LOG" ]; then
      echo "  [cli tail] $(tail -1 "$CLI_LOG")"
    fi
  fi

  # When Flutter finishes first, give the CLI a grace period to complete
  # its broadcast (sendrawtransaction RPC) before the loop times out.
  if [ "$FLUTTER_DONE" = true ] && [ "$CLI_DONE" = false ]; then
    if [ -z "${CLI_GRACE_DEADLINE:-}" ]; then
      CLI_GRACE_DEADLINE=$((ELAPSED + CLI_BROADCAST_GRACE_SECS))
      echo "[script] Flutter done — giving CLI ${CLI_BROADCAST_GRACE_SECS}s grace period to finish broadcast..."
    elif [ "$ELAPSED" -ge "$CLI_GRACE_DEADLINE" ]; then
      echo "[script] CLI grace period expired (${CLI_BROADCAST_GRACE_SECS}s) — checking for raw tx in log..."
      break
    fi
  fi

  if [ "$FLUTTER_DONE" = true ] && [ "$CLI_DONE" = true ]; then
    break
  fi
  sleep 1
  ELAPSED=$((ELAPSED + 1))
done

# Kill any stragglers if we timed out
if [ "$FLUTTER_DONE" = false ]; then
  echo "[script] TIMEOUT: Flutter test did not finish within ${CLI_TIMEOUT_SECS}s"
  kill "$FLUTTER_PID" 2>/dev/null || true
  FLUTTER_PID=""
  FLUTTER_EXIT="timeout"
fi
if [ "$CLI_DONE" = false ]; then
  echo "[script] TIMEOUT: payjoin-cli did not finish within ${CLI_TIMEOUT_SECS}s"
  kill "$CLI_PID" 2>/dev/null || true
  CLI_PID=""
  CLI_EXIT="timeout"
fi

# --- Verify results ---
echo ""
echo "========================================"
echo "  TEST RESULTS"
echo "========================================"

PASS=true

# Check Flutter test result
if [ "$FLUTTER_EXIT" = "0" ]; then
  echo "  [PASS] Flutter integration test (mobile receiver)"
else
  echo "  [FAIL] Flutter integration test (exit code: ${FLUTTER_EXIT:-unknown})"
  PASS=false
fi

# Check payjoin-cli result
if [ "$CLI_EXIT" = "0" ]; then
  echo "  [PASS] payjoin-cli send (exit code 0)"
else
  echo "  [FAIL] payjoin-cli send (exit code: ${CLI_EXIT:-unknown})"
  PASS=false
fi

# Check CLI log for broadcast confirmation (payjoin-cli prints the txid on success)
if [ -s "$CLI_LOG" ]; then
  TXID="$(grep -oE '[0-9a-f]{64}' "$CLI_LOG" | tail -1 || true)"
  if [ -n "$TXID" ]; then
    echo "  [PASS] Transaction broadcast: $TXID"
  elif grep -qiE '(broadcast|sent|success)' "$CLI_LOG" 2>/dev/null; then
    echo "  [INFO] CLI mentions success but no txid found in output"
  else
    echo "  [WARN] No broadcast confirmation in CLI output"
    PASS=false
  fi
else
  echo "  [FAIL] payjoin-cli produced no output (was it started?)"
  PASS=false
fi

echo "========================================"

if [ "$PASS" = true ]; then
  echo "[script] TEST PASSED"
  exit 0
else
  echo "[script] TEST FAILED — logs preserved in $TMPDIR_WORK"
  exit 1
fi
