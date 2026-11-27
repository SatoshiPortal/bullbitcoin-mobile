#!/usr/bin/env bash
set -euo pipefail

# A separate data directory and Secret Service keep restored wallets out of
# both the aggregate suite and the developer's normal desktop keyring.
if [[ "$(uname -s)" != Linux ]]; then
  echo "The isolated RecoverBull integration test requires Linux." >&2
  exit 1
fi
state="$(mktemp -d)"
cleanup() {
  if mountpoint -q "$state/runtime/doc"; then
    fusermount -u "$state/runtime/doc"
  fi
  rm -rf "$state"
}
trap cleanup EXIT
export XDG_DATA_HOME="$state/data" XDG_CONFIG_HOME="$state/config" XDG_RUNTIME_DIR="$state/runtime"
unset GNOME_KEYRING_CONTROL GNOME_KEYRING_PID
mkdir -m 700 -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR" "$state/documents"
printf 'XDG_DOCUMENTS_DIR="%s/documents"\n' "$state" > "$XDG_CONFIG_HOME/user-dirs.dirs"
dbus-run-session -- bash -c '
  set -euo pipefail
  echo "" | gnome-keyring-daemon --unlock --daemonize --components=secrets
  fvm flutter test integration_test/recoverbull_test.dart -d linux --reporter=expanded
'
