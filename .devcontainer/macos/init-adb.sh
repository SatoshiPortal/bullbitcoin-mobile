#!/bin/sh
# Host-side script — runs via the devcontainer `initializeCommand`, NOT inside
# the container.
#
# Exposes the host's adb server to the devcontainer so `flutter devices` inside
# the container sees USB devices attached to the host (e.g. an Android phone).
# The container's adb client reaches it via
#   ADB_SERVER_SOCKET=tcp:host.containers.internal:5037
# (set in devcontainer.json containerEnv).
#
# Why client-to-host instead of USB passthrough: only one adb server may own a
# USB device at a time. The host already owns it, so the container talks to the
# host's server rather than fighting for the device (which also breaks on every
# replug). adb's server binds to 127.0.0.1 by default — unreachable from the
# container's network namespace — so we (re)start it with -a (all interfaces).
#
# SECURITY: -a binds the adb server to 0.0.0.0:5037, so any host on the same
# network can drive it (install APKs, open an adb shell). adb has no per-
# interface bind for its server, so on untrusted networks (cafe/airport Wi-Fi)
# either skip this adb bridge or firewall tcp/5037 to localhost + the podman
# gateway.
#
# NOTE: host and container adb must be the same version or adb refuses to
# connect. The container's platform-tools is whatever sdkmanager ships latest
# (unpinned), so match the host to the container's `adb --version`.
set -e

# No adb on the host (or not on PATH) -> nothing to expose; the container falls
# back to its local (desktop) device only.
command -v adb >/dev/null 2>&1 || exit 0

# Restart the server listening on all interfaces. Detach so initializeCommand
# returns; nohup keeps it alive after this script's process group exits.
adb kill-server >/dev/null 2>&1 || true
nohup adb -a -P 5037 server nodaemon >/dev/null 2>&1 &

# Give it a moment to bind before the container starts probing.
sleep 1
exit 0
