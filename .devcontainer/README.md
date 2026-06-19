# Dev Container

Two host-specific configurations live side by side. They build the **same**
image (the repo-root `Containerfile.tools`) but each folder is
**self-contained** — it carries its own copy of the lifecycle scripts it needs
(they are not shared).
They differ only in the host integration the runtime can provide:

| Config | Use on | Notable extras |
| --- | --- | --- |
| [`linux/devcontainer.json`](linux/devcontainer.json) | Linux hosts | GPU (`/dev/dri`), X11/Wayland forwarding, SSH-agent forwarding, gnome-keyring for the Flutter Linux desktop GUI |
| [`macos/devcontainer.json`](macos/devcontainer.json) | macOS (Apple Silicon) | Rosetta bootstrap; GUI/GPU, SSH-agent and keyring all omitted (the VM can't provide them) |

## Usage

`make devcontainer` auto-selects the config for your host OS (override with
`make devcontainer DEVCONTAINER_OS=linux|macos`). It **reuses an existing
container if one is present** — it only builds/creates when no container exists
yet, otherwise it just (re)starts it (replaying the Linux keyring bootstrap,
which dies on stop). So stopping and starting is safe and never rebuilds.

The container is named after your checkout folder
(`${localWorkspaceFolderBasename}` — `$(notdir $(CURDIR))` in the makefile), so
on the canonical `bullbitcoin-mobile` checkout it is `bullbitcoin-mobile`, not
`bull` (that is only the `--hostname`).

```bash
make devcontainer                          # host-detected
make devcontainer DEVCONTAINER_OS=linux    # force linux
make devcontainer DEVCONTAINER_OS=macos    # force macos
```

> **Applying a config change:** because `make devcontainer` never recreates an
> existing container, edits to `devcontainer.json` / `Containerfile.tools` won't
> take effect until you remove the old container first:
> `podman rm -f "$(basename "$PWD")" && make devcontainer`.

Or invoke the CLI directly (this *will* recreate on a config change):

```bash
devcontainer up --workspace-folder . --config ./.devcontainer/linux/devcontainer.json
devcontainer up --workspace-folder . --config ./.devcontainer/macos/devcontainer.json
```

In VS Code, "Reopen in Container" prompts you to choose between the two.

> The `devcontainer` CLI builds its **own** image (`vsc-bull-…`) from
> `Containerfile.tools`; it does not reuse the `bull-tools` tag from
> `make container-tools` (that one bakes a different `USERNAME` and so shares no
> layer cache). `make devcontainer` therefore has no `container-tools`
> prerequisite — only `container-app`/`android` build `bull-tools`.

## macOS (Apple Silicon) notes

The macOS target is the Android (x86_64-via-Rosetta) build + tests, not the
Linux desktop GUI. The macOS config is a trimmed sibling of the Linux one.

- **Rosetta** must be active in the podman VM, otherwise the linux/amd64 base
  image falls back to QEMU and crashes with SIGSEGV
  ([containers/podman#28181](https://github.com/containers/podman/issues/28181)).
  It is on by default for Apple Silicon machines (podman ≥ 5.1).
  [`macos/macos-setup.sh`](macos/macos-setup.sh) runs automatically via
  `initializeCommand`; if Rosetta is off it sets the marker and restarts the
  machine (a service-only restart is not enough).
- **No GUI / GPU forwarding.** `--device=/dev/dri` and the X11/Wayland mounts
  are dropped: applehv exposes no DRI node and macOS has no Linux display
  server.
- **No SSH-agent forwarding.** Impossible through the podman VM on macOS
  (virtiofs; [containers/podman#23785](https://github.com/containers/podman/issues/23785)).
  The agent socket is not mounted at all; `~/.ssh` is still mounted read-only,
  so key-based (non-agent) auth works.
- **No keyring/dbus bootstrap.** `flutter_secure_storage_linux` (libsecret)
  only exercises the Secret Service when the rendered Linux app runs, which
  macOS can't display — so the gnome-keyring bootstrap the Linux config does at
  `postStart` is omitted.

## adb device bridge (both configs)

[`init-adb.sh`](linux/init-adb.sh) exposes the **host's** adb server to the
container (`ADB_SERVER_SOCKET=tcp:host.containers.internal:5037`) so a host-side
device or emulator is reachable from inside. Note it (re)starts the host adb
server with `-a` (binds `0.0.0.0:5037`) — see the security note in the script
before using it on an untrusted network. Host and container adb versions must
match.
