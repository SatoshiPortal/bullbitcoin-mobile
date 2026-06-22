#!/bin/sh
# Linux host: normalize bind-mount sources for the Linux dev container.
#
# Every bind mount in devcontainer.json is a hard dependency: if its host
# source is missing at create/start time, the container fails to come up.
# This script guarantees every source exists — real when available, harmless
# placeholder when not — so the container starts regardless of whether SSH,
# git, or an agent are set up. Missing pieces degrade gracefully.
#
# The SSH agent socket lives under $HOME so it is reachable by the runtime.
# Wayland needs no action here: the Linux config forwards the host's
# XDG_RUNTIME_DIR at /run/host-runtime and points WAYLAND_DISPLAY at it.
SSH_SOCKET="${HOME}/.ssh-agent-devcontainer.sock"

# ~/.ssh and ~/.gitconfig are bind-mounted into the container; a fresh machine
# may lack either, which would fail the mount.
mkdir -p "${HOME}/.ssh"
[ -e "${HOME}/.gitconfig" ] || touch "${HOME}/.gitconfig"

# X11 socket dir bind-mounted at /tmp/.X11-unix. Absent on headless or
# Wayland-only hosts — create it so the mount never fails (an empty dir just
# means no X11 apps, not a broken container).
mkdir -p /tmp/.X11-unix

# SSH agent: only symlink a *real* agent socket. If no agent is running,
# $SSH_AUTH_SOCK is empty/stale — `ln -sf "" ...` would make a broken link.
# Leave a placeholder file instead so the mount succeeds; the agent is simply
# unavailable inside the container.
if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
  ln -sf "$SSH_AUTH_SOCK" "$SSH_SOCKET"
else
  rm -f "$SSH_SOCKET"
  touch "$SSH_SOCKET"
fi
