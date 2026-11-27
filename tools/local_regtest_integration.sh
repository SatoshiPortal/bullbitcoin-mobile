#!/usr/bin/env bash
set -euo pipefail

# Run standalone integration tests inside a disposable Bitcoin/Electrum network.
# The surrounding Linux build must be prepared before entering the namespace.
engine=${CONTAINER_ENGINE:-docker}
case "$engine" in docker|podman) ;; *) echo "Unsupported container engine" >&2; exit 2 ;; esac
state=$(mktemp -d "${TMPDIR:-/tmp}/bull-local-regtest.XXXXXXXX")
name="bull-local-${state##*.}"
cleanup() {
  for container in "$name-electrs" "$name-bitcoin"; do
    if "$engine" inspect "$container" >/dev/null 2>&1; then
      "$engine" rm -f "$container" >/dev/null || echo "Could not remove $container" >&2
    fi
  done
  rm -rf -- "$state"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

bitcoin=ghcr.io/getumbrel/docker-bitcoind@sha256:21181ae7f34176f6e9541f821b0b2b2e8cb09a00ae28175098b18e70f832edf7
electrs=ghcr.io/vulpemventures/electrs@sha256:999a2218f423c0fb167ee53b282aa7929a9d4abba38ef16f67f407acd00589d4
container_user=()
if [[ "$engine" == docker ]]; then
  container_user=(--user "$(id -u):$(id -g)")
fi
mkdir -p "$state/node"
"$engine" run -d "${container_user[@]}" --network=none --memory=768m --name "$name-bitcoin" \
  -v "$state/node:/node" "$bitcoin" -regtest -datadir=/node -server \
  -listen=0 -printtoconsole=0 -fallbackfee=0.0002 -rpcuser=ci -rpcpassword=ci >/dev/null
core() { "$engine" exec "$name-bitcoin" bitcoin-cli -regtest -datadir=/node -rpcuser=ci -rpcpassword=ci "$@"; }
timeout 45 "$engine" exec "$name-bitcoin" bitcoin-cli -regtest -datadir=/node -rpcuser=ci -rpcpassword=ci -rpcwait getblockchaininfo |
  python3 -c 'import json,sys; assert json.load(sys.stdin)["chain"] == "regtest"'
core createwallet ci >/dev/null
address=$(core -rpcwallet=ci getnewaddress)
core generatetoaddress 110 "$address" >/dev/null
expected=$(core getblockhash 110)
"$engine" run -d "${container_user[@]}" --network="container:$name-bitcoin" --memory=768m \
  --name "$name-electrs" -v "$state/node:/node:ro" "$electrs" \
  --network regtest --daemon-dir /node --daemon-rpc-addr 127.0.0.1:18443 \
  --electrum-rpc-addr 127.0.0.1:50000 --db-dir /tmp/electrs \
  --cookie ci:ci --jsonrpc-import >/dev/null
pid=$("$engine" inspect "$name-bitcoin" --format '{{.State.Pid}}')
net_exec() {
  if [[ "$engine" == podman ]]; then
    podman unshare nsenter -t "$pid" -n -- "$@"
  else
    sudo nsenter -t "$pid" -n -- setpriv --reuid "$(id -u)" --regid "$(id -g)" --init-groups "$@"
  fi
}
net_exec python3 - "$expected" <<'PY'
import hashlib
import json
import socket
import sys
import time

deadline = time.monotonic() + 90
while time.monotonic() < deadline:
    try:
        with socket.create_connection(("127.0.0.1", 50000), timeout=1) as connection:
            connection.sendall(b'{"id":1,"method":"blockchain.block.header","params":[110]}\n')
            reply = json.loads(connection.makefile("rb").readline())
            header = bytes.fromhex(reply["result"])
            if len(header) == 80 and hashlib.sha256(hashlib.sha256(header).digest()).digest()[::-1].hex() == sys.argv[1]:
                break
    except (OSError, ValueError, KeyError, TypeError):
        pass
    time.sleep(0.5)
else:
    raise SystemExit("Electrum did not index the expected regtest block")
PY

export FVM_CACHE_PATH="${FVM_CACHE_PATH:-$HOME/fvm}"
export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export PATH="$CARGO_HOME/bin:$PATH"
for test in integration_test/coins_test.dart integration_test/exchange_rate_test.dart; do
  test_home="$state/$(basename "$test" .dart)"
  mkdir -p "$test_home"/{home/Documents,data,config,cache,tmp,runtime}
  chmod 700 "$test_home/runtime"
  printf 'XDG_DOCUMENTS_DIR="%s/home/Documents"\n' "$test_home" > "$test_home/config/user-dirs.dirs"
  echo "=== $test ==="
  # sudo drops the CI environment; do not let rustup fetch unrelated targets offline.
  net_exec env HOME="$test_home/home" XDG_DOCUMENTS_DIR="$test_home/home/Documents" \
    XDG_DATA_HOME="$test_home/data" XDG_CONFIG_HOME="$test_home/config" \
    XDG_CACHE_HOME="$test_home/cache" XDG_RUNTIME_DIR="$test_home/runtime" TMPDIR="$test_home/tmp" \
    FVM_CACHE_PATH="$FVM_CACHE_PATH" PUB_CACHE="$PUB_CACHE" RUSTUP_HOME="$RUSTUP_HOME" CARGO_HOME="$CARGO_HOME" \
    RUSTUP_AUTO_INSTALL=0 PATH="$PATH" \
    xvfb-run -a dbus-run-session -- bash -c \
    'echo -n ci | gnome-keyring-daemon --unlock --daemonize --components=secrets >/dev/null; exec "$@"' _ \
    fvm flutter test "$test" -d linux --no-pub --reporter expanded \
    --dart-define=BULL_REGTEST_HOST=127.0.0.1 --dart-define=BULL_REGTEST_VALIDATION=true
done
