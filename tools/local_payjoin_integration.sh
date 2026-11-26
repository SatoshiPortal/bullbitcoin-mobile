#!/usr/bin/env bash
set -euo pipefail

# The binaries and Linux application must be built before entering the isolated network.
: "${BULL_PAYJOIN_TEST_PEER:?Set the path to the pinned payjoin-cli binary}"
: "${BULL_PAYJOIN_MAILROOMS:?Set the path to the local mailrooms binary}"
[[ -x "$BULL_PAYJOIN_TEST_PEER" && -x "$BULL_PAYJOIN_MAILROOMS" ]] || {
  echo "Payjoin fixture binaries must be executable" >&2
  exit 2
}
engine=${CONTAINER_ENGINE:-docker}
case "$engine" in docker|podman) ;; *) echo "Unsupported container engine" >&2; exit 2 ;; esac
state=$(mktemp -d "${TMPDIR:-/tmp}/bull-payjoin-regtest.XXXXXXXX")
name="bull-payjoin-${state##*.}"
cleanup() {
  for container in "$name-mailrooms" "$name-electrs" "$name-bitcoin"; do
    if "$engine" inspect "$container" >/dev/null 2>&1; then
      "$engine" rm -f "$container" >/dev/null || echo "Could not remove $container" >&2
    fi
  done
  rm -rf -- "$state"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Core 32 currently returns a PSBT the pinned peer cannot parse.
bitcoin=ghcr.io/getumbrel/docker-bitcoind@sha256:89185fc2792a9824cbe18f7ad4ead02a3a9a14adf5b34eb42f60ebec36201fa0
electrs=ghcr.io/vulpemventures/electrs@sha256:999a2218f423c0fb167ee53b282aa7929a9d4abba38ef16f67f407acd00589d4
runtime=docker.io/library/python@sha256:a83ba18aef0f865b1a4a611c2cf460fe446f2795673bbb9fe43be570439e3b39
mkdir -p "$state/node" "$state/mailrooms"
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$state/mailrooms/key.pem" -out "$state/mailrooms/cert.pem" \
  -days 1 -subj /CN=localhost -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' \
  -addext 'basicConstraints=critical,CA:FALSE' >/dev/null 2>&1
openssl x509 -in "$state/mailrooms/cert.pem" -outform der -out "$state/mailrooms/cert.der"
cert=$(base64 -w0 "$state/mailrooms/cert.der")
pin=$(sha256sum "$state/mailrooms/cert.der" | cut -d' ' -f1)
"$engine" run -d --pull=never --network=none --memory=768m --name "$name-bitcoin" \
  -v "$state/node:/node" "$bitcoin" -regtest -datadir=/node -server \
  -listen=0 -printtoconsole=0 -fallbackfee=0.0002 -rpcuser=ci -rpcpassword=ci >/dev/null
core() { "$engine" exec "$name-bitcoin" bitcoin-cli -regtest -datadir=/node -rpcuser=ci -rpcpassword=ci "$@"; }
timeout 45 "$engine" exec "$name-bitcoin" bitcoin-cli -regtest -datadir=/node -rpcuser=ci -rpcpassword=ci -rpcwait getblockchaininfo |
  python3 -c 'import json,sys; assert json.load(sys.stdin)["chain"] == "regtest"'
core createwallet ci >/dev/null
address=$(core -rpcwallet=ci getnewaddress)
core generatetoaddress 110 "$address" >/dev/null
expected=$(core getblockhash 110)
"$engine" run -d --pull=never --network="container:$name-bitcoin" --memory=768m --name "$name-electrs" \
  -v "$state/node:/node:ro" "$electrs" --network regtest --daemon-dir /node \
  --daemon-rpc-addr 127.0.0.1:18443 --electrum-rpc-addr 127.0.0.1:50000 \
  --db-dir /tmp/electrs --cookie ci:ci --jsonrpc-import >/dev/null
"$engine" run -d --pull=never --network="container:$name-bitcoin" --memory=512m --name "$name-mailrooms" \
  -v "$state/mailrooms:/data" -v "$BULL_PAYJOIN_MAILROOMS:/mailrooms:ro" \
  --entrypoint /mailrooms "$runtime" >/dev/null
pid=$("$engine" inspect "$name-bitcoin" --format '{{.State.Pid}}')
net_exec() {
  if [[ "$engine" == podman ]]; then
    podman unshare nsenter -t "$pid" -n -- "$@"
  else
    sudo nsenter -t "$pid" -n -- setpriv --reuid "$(id -u)" --regid "$(id -g)" --init-groups "$@"
  fi
}
net_exec python3 - "$state/mailrooms/cert.pem" <<'PY'
import ssl
import sys
import time
import urllib.request

context = ssl.create_default_context(cafile=sys.argv[1])
for host, port in (("localhost", 8040), ("127.0.0.1", 8041)):
    deadline = time.monotonic() + 30
    while True:
        try:
            with urllib.request.urlopen(f"https://{host}:{port}/health", context=context, timeout=2) as response:
                if response.status != 200:
                    raise RuntimeError("Mailroom health failed")
            break
        except (OSError, RuntimeError):
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.25)
PY
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
test_home="$state/app"
mkdir -p "$test_home"/{home/Documents,data,config,cache,tmp,runtime}
chmod 700 "$test_home/runtime"
printf 'XDG_DOCUMENTS_DIR="%s/home/Documents"\n' "$test_home" > "$test_home/config/user-dirs.dirs"
net_exec env BULL_PAYJOIN_TEST_PEER="$BULL_PAYJOIN_TEST_PEER" BULL_PAYJOIN_TEST_CERT="$state/mailrooms/cert.der" \
  HOME="$test_home/home" XDG_DOCUMENTS_DIR="$test_home/home/Documents" \
  XDG_DATA_HOME="$test_home/data" XDG_CONFIG_HOME="$test_home/config" \
  XDG_CACHE_HOME="$test_home/cache" XDG_RUNTIME_DIR="$test_home/runtime" TMPDIR="$test_home/tmp" \
  FVM_CACHE_PATH="$FVM_CACHE_PATH" PUB_CACHE="$PUB_CACHE" RUSTUP_HOME="$RUSTUP_HOME" CARGO_HOME="$CARGO_HOME" PATH="$PATH" \
  xvfb-run -a dbus-run-session -- bash -c \
  'echo -n ci | gnome-keyring-daemon --unlock --daemonize --components=secrets >/dev/null; exec "$@"' _ \
  fvm flutter test integration_test/payjoin_test.dart -d linux --no-pub --reporter expanded \
  --dart-define=BULL_REGTEST_HOST=127.0.0.1 --dart-define=BULL_REGTEST_VALIDATION=true \
  --dart-define=BULL_PAYJOIN_CERT_DER_BASE64="$cert" --dart-define=BULL_PAYJOIN_CERT_SHA256="$pin"
