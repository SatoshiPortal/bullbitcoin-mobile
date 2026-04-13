#!/bin/sh
# Normalize SSH agent socket path for devcontainer mount
case "$(uname)" in
  Linux)
    # Symlink real SSH agent socket
    ln -sf "$SSH_AUTH_SOCK" /tmp/ssh-agent.sock
    ;;
  Darwin)
    # Create dummy so the mount doesn't fail (SSH agent not supported on macOS Podman)
    rm -f /tmp/ssh-agent.sock
    touch /tmp/ssh-agent.sock
    ;;
esac
