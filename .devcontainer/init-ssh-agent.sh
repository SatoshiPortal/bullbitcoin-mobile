#!/bin/sh
# Normalize SSH agent socket path for devcontainer mount.
# Place under $HOME so the file is visible inside the podman-machine VM on macOS
# (the VM bind-mounts /Users from the host but not /tmp).
SOCKET="${HOME}/.ssh-agent-devcontainer.sock"
case "$(uname)" in
  Linux)
    ln -sf "$SSH_AUTH_SOCK" "$SOCKET"
    ;;
  Darwin)
    # SSH agent not supported on macOS podman; create dummy so mount doesn't fail
    rm -f "$SOCKET"
    touch "$SOCKET"
    ;;
esac
