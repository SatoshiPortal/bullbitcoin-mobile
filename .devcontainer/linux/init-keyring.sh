#!/bin/sh
# Bootstrap a session DBus + gnome-keyring inside the dev container so libsecret
# (used by flutter_secure_storage_linux) has a Secret Service provider to talk
# to. Idempotent — safe to invoke on every container start.
#
# Each step is gated on a *functional* check (can we actually use it?) rather
# than a presence check (does a file exist?). The earlier presence-based
# version passed when a daemon had died leaving a stale socket, or when the
# keyring file existed but was locked with a forgotten password — and the app
# then died at init with libsecret_error: Failed to unlock the keyring.
set -e
DBUS_SOCKET=/tmp/dbus-session.sock
KEYRING_PASSWORD=bull

export DBUS_SESSION_BUS_ADDRESS="unix:path=$DBUS_SOCKET"

# 1. Session DBus on a fixed socket path. Replace the daemon if the socket
#    file exists but no daemon is listening on it (stale socket from a crash).
dbus_ok() {
  # Peer.Ping on the bus daemon itself succeeds iff the bus is alive and
  # accepting connections — a stale socket file fails this.
  timeout 2 dbus-send --session --dest=org.freedesktop.DBus \
    --print-reply / org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1
}
if ! dbus_ok; then
  rm -f "$DBUS_SOCKET"
  setsid dbus-daemon \
    --session \
    --address="unix:path=$DBUS_SOCKET" \
    --nofork --syslog-only >/dev/null 2>&1 &
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    dbus_ok && break
    sleep 0.2
  done
fi

# 2. gnome-keyring-daemon (Secret Service provider). The probe below tests
#    the full path the app uses: bus reachable → daemon registered on it →
#    default collection unlocked. A running-but-broken daemon (registered on
#    a previous bus, or with a locked collection) fails this and is replaced.
keyring_ok() {
  # Store a throwaway secret then clear it. Succeeds only if the daemon is
  # registered on org.freedesktop.secrets AND the default collection is
  # unlocked. `timeout` guards against the libsecret prompt-for-password
  # behaviour that would otherwise hang in a headless container.
  printf 'probe' | timeout 3 secret-tool store --label='keyring-probe' \
    app keyring-probe >/dev/null 2>&1 || return 1
  timeout 2 secret-tool clear app keyring-probe >/dev/null 2>&1 || return 1
}
if ! keyring_ok; then
  pkill -x gnome-keyring-d 2>/dev/null || true
  sleep 0.3
  printf '%s' "$KEYRING_PASSWORD" | gnome-keyring-daemon \
    --daemonize --unlock --components=secrets >/dev/null 2>&1 || true
fi

# 3. Bootstrap a default collection if needed. gnome-keyring-daemon doesn't
#    create one automatically — libsecret callers get KeyringLocked errors
#    until one exists. Run unconditionally: store-then-clear leaves no
#    residue, and is the same primitive keyring_ok uses, so it's cheap and
#    idempotent.
printf '%s' "$KEYRING_PASSWORD" | secret-tool store --label='bootstrap' \
  app bootstrap >/dev/null 2>&1 || true
secret-tool clear app bootstrap >/dev/null 2>&1 || true

# 4. Final assertion. Better to fail postStartCommand here, where the cause
#    is obvious, than to die mid-app-init with a stack trace pointing at
#    flutter_secure_storage.
if ! keyring_ok; then
  echo "init-keyring.sh: keyring still not usable. Try:" >&2
  echo "  killall -9 gnome-keyring-daemon dbus-daemon" >&2
  echo "  rm -f /tmp/dbus-session.sock" >&2
  echo "  rm -rf ~/.local/share/keyrings" >&2
  echo "  .devcontainer/linux/init-keyring.sh" >&2
  exit 1
fi
