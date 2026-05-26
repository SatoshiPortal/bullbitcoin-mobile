#!/bin/sh
# Normalize host socket paths for devcontainer mounts.
# Targets are fixed (/tmp/ssh-agent.sock, /tmp/wayland.sock) so devcontainer.json
# doesn't depend on host env vars that may be unset (XDG_RUNTIME_DIR, WAYLAND_DISPLAY).
case "$(uname)" in
  Linux)
    # SSH agent: symlink the real socket
    ln -sf "$SSH_AUTH_SOCK" /tmp/ssh-agent.sock

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
    rm -f /tmp/ssh-agent.sock /tmp/wayland.sock
    touch /tmp/ssh-agent.sock /tmp/wayland.sock
    ;;
esac
