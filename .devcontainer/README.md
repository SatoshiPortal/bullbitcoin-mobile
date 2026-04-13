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
