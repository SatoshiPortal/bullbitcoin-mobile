# Dev Container

## Prerequisites

### macOS (Apple Silicon)

The dev container runs x86_64 via Podman with Rosetta emulation.

**Known issue:** Podman may report `Rosetta: true` in its config but fail to actually activate it, causing x86_64 binaries (like `rustc`) to fall back to QEMU and crash with SIGSEGV.

Verify Rosetta is active:

```bash
podman machine ssh -- cat /proc/sys/fs/binfmt_misc/rosetta
```

If the file doesn't exist, Rosetta is **not** active. Fix it:

```bash
podman machine ssh -- sudo touch /etc/containers/enable-rosetta
podman machine ssh -- sudo systemctl restart rosetta-activation.service
```

Then verify again — you should see `enabled` with an interpreter path to `/mnt/rosetta`.

See [containers/podman#28181](https://github.com/containers/podman/issues/28181) for details.

#### SSH agent forwarding

Podman on macOS cannot mount host Unix sockets into containers (the VM layer blocks it). To forward your SSH agent, run this in a separate terminal **before** starting the container:

```bash
podman machine ssh -- -R /tmp/ssh-agent.sock:"$SSH_AUTH_SOCK" -N
```

This must stay running for the duration of your session.

See [containers/podman#23785](https://github.com/containers/podman/issues/23785) for details.

## Usage

```bash
devcontainer up --workspace-folder . --config ./.devcontainer/devcontainer.json
```
