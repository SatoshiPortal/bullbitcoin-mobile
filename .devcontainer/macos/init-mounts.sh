#!/bin/sh
# macOS host: guarantee the bind-mount sources exist before the container starts.
#
# Every bind mount in devcontainer.json is a hard dependency — a missing source
# fails container create/start. A fresh machine may lack ~/.ssh or ~/.gitconfig,
# both of which are mounted into the container, so we create them if absent.
#
# That's all macOS needs: SSH agent forwarding is impossible through the podman
# VM (virtiofs; containers/podman#23785) and there is no X11/Wayland to forward,
# so unlike the Linux config there is no socket to normalize here.
mkdir -p "${HOME}/.ssh"
[ -e "${HOME}/.gitconfig" ] || touch "${HOME}/.gitconfig"
