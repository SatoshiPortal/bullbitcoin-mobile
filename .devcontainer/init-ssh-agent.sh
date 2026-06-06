#!/bin/sh
# Normalize host paths for devcontainer mounts.
#
# Every bind mount in devcontainer.json is a hard dependency: if its host
# source is missing at create/start time, the container fails to come up
# (this is what the stale /tmp/ssh-agent.sock mount did after a reboot).
# This script guarantees every bind source exists — real when available,
# harmless placeholder when not — so the container starts on any machine
# regardless of whether SSH, git, an agent, or a display are set up.
# Missing pieces degrade gracefully instead of breaking startup.
#
# The SSH agent socket lives under $HOME (not /tmp) so it's visible inside the
# podman-machine VM on macOS, which bind-mounts /Users from the host but not
# /tmp. Wayland stays in /tmp since it's Linux-only (macOS has no Wayland).
SSH_SOCKET="${HOME}/.ssh-agent-devcontainer.sock"

# Bind sources that must exist on every host, regardless of OS.
# ~/.ssh and ~/.gitconfig are bind-mounted read-only into the container;
# a fresh machine may lack either, which would fail the mount.
mkdir -p "${HOME}/.ssh"
[ -e "${HOME}/.gitconfig" ] || touch "${HOME}/.gitconfig"

case "$(uname)" in
  Linux)
    # X11 socket dir: bind-mounted at /tmp/.X11-unix. Absent on headless or
    # Wayland-only hosts — create it so the mount never fails (an empty dir
    # just means no X11 apps, not a broken container).
    mkdir -p /tmp/.X11-unix

    # SSH agent: only symlink a *real* agent socket. If no agent is running,
    # $SSH_AUTH_SOCK is empty/stale — `ln -sf "" ...` would make a broken
    # link. Leave a placeholder file instead so the mount succeeds; the
    # agent is simply unavailable inside the container.
    if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
      ln -sf "$SSH_AUTH_SOCK" "$SSH_SOCKET"
    else
      rm -f "$SSH_SOCKET"
      touch "$SSH_SOCKET"
    fi

    # Wayland: symlink the real socket if running under Wayland; else dummy file
    if [ -n "$WAYLAND_DISPLAY" ] && [ -n "$XDG_RUNTIME_DIR" ] \
       && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
      ln -sf "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" /tmp/wayland.sock
    else
      rm -f /tmp/wayland.sock
      touch /tmp/wayland.sock
    fi
    ;;
  Darwin)
    # X11/Wayland/agent forwarding aren't supported on macOS Podman — create
    # dummies so the mounts don't fail.
    mkdir -p /tmp/.X11-unix
    rm -f "$SSH_SOCKET" /tmp/wayland.sock
    touch "$SSH_SOCKET" /tmp/wayland.sock
    ;;
esac
