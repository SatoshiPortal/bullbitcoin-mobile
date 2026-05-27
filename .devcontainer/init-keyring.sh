#!/bin/sh
# Bootstrap a session DBus + gnome-keyring inside the dev container so libsecret
# (used by flutter_secure_storage_linux) has a Secret Service provider to talk
# to. Idempotent — safe to invoke on every container start.
set -e
DBUS_SOCKET=/tmp/dbus-session.sock
KEYRING_PASSWORD=bull

# 1. Session DBus on a fixed socket path (matches DBUS_SESSION_BUS_ADDRESS
#    in devcontainer.json so every child process — including `flutter run`
#    launched from any shell — talks to the same bus).
if [ ! -S "$DBUS_SOCKET" ]; then
  setsid dbus-daemon \
    --session \
    --address="unix:path=$DBUS_SOCKET" \
    --nofork --syslog-only >/dev/null 2>&1 &
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -S "$DBUS_SOCKET" ] && break
    sleep 0.2
  done
fi
export DBUS_SESSION_BUS_ADDRESS="unix:path=$DBUS_SOCKET"

# 2. gnome-keyring-daemon (Secret Service provider). Unlocks the default
#    keyring with the dummy password "bull" used at creation (see step 3).
#    The keyring file persists across container restarts via the named
#    volume mounted at ~/.local/share/keyrings.
#    Dev-only — the keyring never leaves the container.
if ! pgrep -x gnome-keyring-d >/dev/null 2>&1; then
  printf '%s' "$KEYRING_PASSWORD" | gnome-keyring-daemon --daemonize --unlock --components=secrets \
    >/dev/null 2>&1 || true
fi

# 3. Initialize a default keyring on first run. gnome-keyring-daemon doesn't
#    create a default collection automatically; libsecret callers (e.g.,
#    flutter_secure_storage) get KeyringLocked errors until one exists.
#    The `secret-tool store` triggers creation of the default collection on
#    first call; we immediately clear the bootstrap entry, leaving an empty
#    but initialized keyring. Idempotent — subsequent runs skip if a
#    keyring file already exists.
if [ ! -f "$HOME/.local/share/keyrings/Default_keyring.keyring" ] && \
   [ ! -f "$HOME/.local/share/keyrings/login.keyring" ]; then
  printf '%s' "$KEYRING_PASSWORD" | secret-tool store --label="bootstrap" app bootstrap 2>/dev/null || true
  secret-tool clear app bootstrap 2>/dev/null || true
fi
