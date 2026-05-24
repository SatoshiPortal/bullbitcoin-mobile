# Dev Container

## Usage

```bash
devcontainer up --workspace-folder . --config ./.devcontainer/devcontainer.json
```

## macOS (Apple Silicon)

Before starting the container, run the setup script:

```bash
.devcontainer/macos-setup.sh
```

This ensures Rosetta is active in the Podman VM. Without it, x86_64 binaries fall back to QEMU and crash with SIGSEGV. See [containers/podman#28181](https://github.com/containers/podman/issues/28181).

**Note:** SSH agent forwarding is not supported on macOS due to Podman's inability to mount host Unix sockets into containers through the VM layer. See [containers/podman#23785](https://github.com/containers/podman/issues/23785).

## Debugging on a physical Android device (USB, Linux host)

The USB device is attached to the host, not the container, so the container can't see it directly. Instead, run the `adb` server on the host and point the container's `adb`/`flutter` at it.

On the host:

- Get an adb binary that matches the one in the container, you can copy it out of the running container:
`podman cp bullbitcoin-mobile:/opt/android-sdk/platform-tools/adb ~/.local/bin/adb`

Start the adb server listening on all interfaces (-a). 
`~/.local/bin/adb kill-server && ~/.local/bin/adb -a nodaemon server`

Then, inside the container

`export ADB_SERVER_SOCKET=tcp:host.containers.internal:5037`

Add the `export` line to your container shell profile if you don't want to repeat it each session.

Under rootless Podman with the pasta backend, `host.containers.internal` resolves to a link-local address that pasta forwards to the host. Don't use the host's LAN IP (`ip route get 1.1.1.1 | grep src`).  Under pasta the container can't route to the host's own LAN address and the connection is refused. If `host.containers.internal` doesn't resolve, check what Podman wrote to the container's `/etc/hosts` and use that address directly.

**Note:** this depends on your Podman version and whether you run rootless or rootful, rootful uses a netavark bridge with a real host gateway, and `host.containers.internal` resolution changed across the 4.7 to 5.x transition. Verified on rootless Podman 5.x with pasta; on a different setup inspect `/etc/hosts` and `/proc/net/route`.

**Security note:** `adb -a` exposes the adb server (port 5037) to your whole local network for as long as it runs. Only run it on networks you trust, or restrict port 5037 with a host firewall.
