#!/bin/sh
# Normalize host socket paths for devcontainer mounts.
# Targets are fixed so devcontainer.json doesn't depend on host env vars that
# may be unset (XDG_RUNTIME_DIR, WAYLAND_DISPLAY).
#
# The SSH agent socket lives under $HOME (not /tmp) so it's visible inside the
# podman-machine VM on macOS, which bind-mounts /Users from the host but not
# /tmp. Wayland stays in /tmp since it's Linux-only (macOS has no Wayland).
SSH_SOCKET="${HOME}/.ssh-agent-devcontainer.sock"
case "$(uname)" in
  Linux)
    # SSH agent: symlink the real socket
    ln -sf "$SSH_AUTH_SOCK" "$SSH_SOCKET"

    # Wayland: symlink the real socket if running under Wayland; otherwise dummy file
    if [ -n "$WAYLAND_DISPLAY" ] && [ -n "$XDG_RUNTIME_DIR" ] \
       && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
      ln -sf "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" /tmp/wayland.sock
    else
      rm -f /tmp/wayland.sock
      touch /tmp/wayland.sock
    fi
    ;;
  Darwin)
    # Dummies so the mounts don't fail (neither socket is supported on macOS Podman)
    rm -f "$SSH_SOCKET" /tmp/wayland.sock
    touch "$SSH_SOCKET" /tmp/wayland.sock
    ;;
esac
