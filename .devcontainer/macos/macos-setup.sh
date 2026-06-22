#!/bin/sh
# Setup script for macOS (Apple Silicon) users. Runs automatically via the
# macOS devcontainer's initializeCommand; can also be run by hand before:
# devcontainer up --workspace-folder . --config ./.devcontainer/macos/devcontainer.json
#
# Ensures Rosetta is active in the Podman VM so the linux/amd64 base image runs
# natively-translated instead of falling back to QEMU (which SIGSEGVs).
# See https://github.com/containers/podman/issues/28181

set -e

rosetta_active() {
  podman machine ssh -- cat /proc/sys/fs/binfmt_misc/rosetta >/dev/null 2>&1
}

if rosetta_active; then
  echo "Rosetta is active."
  exit 0
fi

# Rosetta is on by default for Apple Silicon podman machines (podman >= 5.1), so
# reaching here usually means an older or hand-built machine. Enabling it is a
# boot-time concern: the rosetta-activation.service mounts virtiofs and registers
# the binfmt handler during startup, so the marker must be set and the MACHINE
# restarted — restarting only the unit does not reliably remount/re-register.
echo "Rosetta is not active in the Podman VM. Enabling (requires a machine restart)..."
podman machine ssh -- sudo touch /etc/containers/enable-rosetta
podman machine stop
podman machine start

if rosetta_active; then
  echo "Rosetta enabled successfully."
else
  echo "Failed to enable Rosetta automatically." >&2
  echo "Recreate the machine with Rosetta, e.g.:" >&2
  echo "  podman machine rm && podman machine init --rosetta && podman machine start" >&2
  exit 1
fi
