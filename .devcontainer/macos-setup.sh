#!/bin/sh
# Setup script for macOS (Apple Silicon) users
# Run this before: devcontainer up --workspace-folder . --config ./.devcontainer/devcontainer.json

set -e

# Ensure Rosetta is active in the Podman VM
# See https://github.com/containers/podman/issues/28181
if ! podman machine ssh -- cat /proc/sys/fs/binfmt_misc/rosetta > /dev/null 2>&1; then
  echo "Rosetta is not active in the Podman VM, enabling it..."
  podman machine ssh -- sudo touch /etc/containers/enable-rosetta
  podman machine ssh -- sudo systemctl restart rosetta-activation.service
  if podman machine ssh -- cat /proc/sys/fs/binfmt_misc/rosetta > /dev/null 2>&1; then
    echo "Rosetta enabled successfully."
  else
    echo "Failed to enable Rosetta." >&2
    exit 1
  fi
else
  echo "Rosetta is active."
fi
