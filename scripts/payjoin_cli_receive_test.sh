#!/usr/bin/env bash
# Orchestrates the payjoin-cli receiver <-> mobile sender integration test.
#
# Steps:
#   1. Start payjoin-cli as a receiver — it prints a BIP21 pjURI to stdout
#   2. Wait for that URI to appear
#   3. Pass the URI to `flutter test` as PJ_BIP21_URI
#   4. Clean up the CLI process on exit
#
# Required env / .env variables:
#   PAYJOIN_CLI_SOURCE_DIR   Path to the payjoin-cli Cargo crate
#   PAYJOIN_CLI_RPCHOST      bitcoind RPC URL  (e.g. http://localhost:18332/wallet/test)
#   PAYJOIN_CLI_COOKIE_FILE  Path to bitcoind .cookie  — OR use RPCUSER + RPCPASSWORD
#   PAYJOIN_CLI_RPCUSER
#   PAYJOIN_CLI_RPCPASSWORD
#
# Optional:
#   CARGO_PATH               Full path to cargo binary (default: cargo)
#   PAYJOIN_CLI_OHTTP_RELAY  OHTTP relay URL
#   PAYJOIN_CLI_PJ_DIRECTORY Payjoin directory URL
#   PAYJOIN_CLI_SEND_AMOUNT_SAT  Amount in sat for the CLI to receive (default: 2000)
#   BIP21_WAIT_SECS          Seconds to wait for BIP21 URI (default: 120 — first run compiles)

set -euo pipefail

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
BIP21_WAIT_SECS="${BIP21_WAIT_SECS:-120}"

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
CLI_PID=""

cleanup() {
  if [ -n "$CLI_PID" ]; then
    echo "[script] Killing payjoin-cli (PID $CLI_PID)..."
    kill "$CLI_PID" 2>/dev/null || true
  fi
  echo "[script] === payjoin-cli output ==="
  cat "$CLI_LOG" 2>/dev/null || true
  echo "[script] === end payjoin-cli output ==="
  rm -rf "$TMPDIR_WORK"
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

# --- Start payjoin-cli receiver ---
echo "[script] Starting payjoin-cli receiver (amount: ${AMOUNT_SAT} sat)..."
"$CARGO_PATH" run \
  --manifest-path "$CLI_SOURCE_DIR/Cargo.toml" \
  -- \
  "${RPC_ARGS[@]}" \
  --db-path "$DB_PATH" \
  --ohttp-relays "$OHTTP_RELAY" \
  --pj-directory "$PJ_DIRECTORY" \
  receive "$AMOUNT_SAT" \
  > "$CLI_LOG" 2>&1 &
CLI_PID=$!

# --- Wait for BIP21 URI ---
echo "[script] Waiting up to ${BIP21_WAIT_SECS}s for BIP21 URI (first run compiles Rust — this may take a while)..."
BIP21_URI=""
for _ in $(seq 1 "$BIP21_WAIT_SECS"); do
  if grep -qm1 "^bitcoin:" "$CLI_LOG" 2>/dev/null; then
    BIP21_URI="$(grep -m1 "^bitcoin:" "$CLI_LOG")"
    break
  fi
  # Exit early if the CLI process died
  if ! kill -0 "$CLI_PID" 2>/dev/null; then
    echo "[script] ERROR: payjoin-cli exited unexpectedly. Output:"
    cat "$CLI_LOG"
    exit 1
  fi
  sleep 1
done

if [ -z "$BIP21_URI" ]; then
  echo "[script] ERROR: payjoin-cli did not print a BIP21 URI within ${BIP21_WAIT_SECS}s. Output:"
  cat "$CLI_LOG"
  exit 1
fi

# --- Patch fragment separator: payjoin-cli v1.x uses '-' but payjoin-flutter v0.23 expects '+' ---
# The pj= URL's fragment (after %23) uses '-' between params; the mobile lib expects '+'
if [[ "$BIP21_URI" == *"%23"* ]]; then
  PREFIX="${BIP21_URI%%\%23*}"
  SUFFIX="${BIP21_URI#*%23}"
  SUFFIX="${SUFFIX//-/+}"
  BIP21_URI="${PREFIX}%23${SUFFIX}"
  echo "[script] Patched BIP21 fragment separators (- -> +)"
fi
echo "[script] BIP21 URI: $BIP21_URI"

# --- Run Flutter integration test ---
echo "[script] Running flutter integration test..."
cd "$REPO_DIR"
DEVICE_ID="${ANDROID_DEVICE_ID:-$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')}"
if [ -z "$DEVICE_ID" ]; then
  echo "[script] ERROR: No Android device/emulator found. Start an emulator and retry."
  exit 1
fi
echo "[script] Using device: $DEVICE_ID"

fvm flutter test \
  --device-id="$DEVICE_ID" \
  --dart-define="PJ_BIP21_URI=$BIP21_URI" \
  integration_test/payjoin_cli_receive_integration_test.dart \
  --reporter=compact

echo "[script] Done."
