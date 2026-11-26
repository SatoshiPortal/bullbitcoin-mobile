# onion

Embedded Tor client and loopback SOCKS5 proxy for Bull Bitcoin Mobile, built on
[Arti](https://gitlab.torproject.org/tpo/core/arti).

> **This is not an official Tor Project product.**
> Tor is a trademark of The Tor Project; all rights reserved — <https://torproject.org>.
> This software is not endorsed or sponsored by, or affiliated with, the Tor Project.
> It is a third-party integration that connects to the Tor network.

## Status

The Rust implementation, flutter_rust_bridge bindings, and mobile Snowflake
transport are complete. The package is consumed through
`package:rust_bindings/onion.dart`; its hermetic Rust suite exercises the lifecycle,
bridge configuration, and SOCKS protocol without a device attached.

## Why this exists

It replaces `github.com/Foundation-Devices/tor`, which the app currently
depends on. That package works, but:

- It is pinned to **arti 1.7.0** (October 2025) while upstream is on **2.5.0**.
  Its two commits in the past year could not keep pace with arti's monthly
  releases, and arti's own README warns that an integration which is not kept
  current "might stop working entirely".
- Its Rust wrapper reduces the whole of `BootstrapStatus` to a single `bool`
  captured once at startup. Everything arti knows about *why* it is stuck —
  including whether the connection is being filtered — is computed and then
  discarded at the FFI boundary. The failure resurfaces later as an
  unattributable RecoverBull transport error.
- `tor_client_bootstrap` reconstructs a `Box` from the client pointer and never
  leaks it back, so the pointer Dart keeps is dangling afterwards. Not
  currently triggered — nothing calls `setClientDormant` — but it is armed.

## Design decisions

**No dependency on the `arti` crate.** Since arti 2.0.0 every API in that crate
is marked experimental and "likely to get moved into other crates or removed".
Depending on `arti::proxy::run_proxy` is what made the previous wrapper
expensive to upgrade. We speak SOCKS5 ourselves via `tor-socksproto`, a normal
non-experimental crate, and keep `arti-client` as the only high-level
dependency.

**The SOCKS proxy is load-bearing, not general-purpose.** RecoverBull's Dart
HTTP client already accepts a SOCKS5 endpoint. Binding `TorClient::connect`
directly would require a separate HTTP transport over Arti streams. The proxy
therefore accepts only `.onion` destinations; it cannot accidentally route
clearnet or IP traffic through this package.

**`native-tls`, not `rustls`.** The bull_sdk aggregate already links both `ring`
and `aws-lc-rs` transitively, which makes rustls 0.23 panic when it
auto-selects a provider (see the pin in `lwk-dart/rust/Cargo.toml`). arti's
default is native-tls and `openssl-sys` is already in the aggregate lock.

**`static` feature.** Vendors OpenSSL and SQLite. Required on Android, which
has neither. Upstream marks it non-additive, so it is set here rather than left
to a consumer to remember.

**Nothing from `arti_client` crosses the public API.** Every exported type is
defined in this crate, so an upstream change is absorbed here instead of
rippling into the app, and the Dart side can switch exhaustively.

**Snowflake is native and unmanaged.** Android and iOS use the precompiled
IPtProxy 5.6.0 mobile library. It binds a local SOCKS5 listener; Arti's
`tor-ptmgr` connects to that listener as an unmanaged transport and never tries
to launch a subprocess. Native process-wide leases keep one listener alive
while multiple Flutter engines use it. The Android AAR and both iOS binary
slices are SHA-256 verified during every native build. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for provenance and licensing.

**Direct and Snowflake clients are separate.** `TorService::start()` remains
the direct path. For Snowflake, acquire `SnowflakeTransport`, pass its port to
`TorService::start_with_snowflake()`, and release the native lease after the Tor
service stops. Selecting Snowflake does not prove it connected;
`TorStatus::ready_for_traffic` must also be true before the UI says it is
connected through Snowflake.

**Every SOCKS session has circuit isolation.** The initial listener and each
listener returned by `TorService::open_session()` use a distinct
`TorClient::isolated_client()`. Arti guarantees that streams from two such
clients never share circuits, including hidden-service directory,
introduction, and rendezvous circuits. Sessions still share the root
configuration, directory state, guards, channels, transport, and observable
process/network timing; this is unlinkability between application streams, not
protection from a global observer. Stopping one session leaves the others
running. Stopping or dropping `TorService` stops every registered session.

## What it provides

```rust
let svc = TorService::start(state_dir, cache_dir, 0).await?;  // binds, does not bootstrap
let port = svc.socks_port();                                   // real bound port
let mut events = svc.status_stream();                          // progress + blockage
svc.bootstrap().await?;
let electrum = svc.open_session(0).await?;                     // different circuits
let rtt = svc.probe("check.torproject.org", 443, timeout).await?;
electrum.stop().await;
svc.stop().await;
```

On Android and iOS, the equivalent Snowflake setup from Dart is:

```dart
final snowflakePort = await SnowflakeTransport.start();
final service = await TorService.startWithSnowflake(
  stateDir: stateDir,
  cacheDir: cacheDir,
  socksPort: 0,
  snowflakePort: snowflakePort,
);
try {
  await service.bootstrap();
} finally {
  await service.stop();
  await SnowflakeTransport.stop();
}
```

### Status is not monotonic

arti documents that a client can become *less* bootstrapped over time — when
connectivity drops, or when its directory information expires. Consumers must
treat each `TorStatus` as the current truth rather than latching the first
`ready_for_traffic`. This is why the status is a stream and not a one-shot
boolean.

### Stage text

`TorStatus::stage` carries arti's own one-line description of the snapshot
(the `Display` of `BootstrapStatus`), for example `36%: connecting
successfully; directory is fetching authority certificates (0/9)`, or
`Stuck at …` followed by the blockage while arti believes it is stuck. arti designs that string for humans,
not parsers, and its wording can change between releases: show it as
diagnostic detail or log it, but act on `fraction`, `ready_for_traffic` and
`blockage`. It is not localized, and it is empty once the service has stopped.

### Blockage kinds

`TorStatus::blockage` carries the diagnostic the old wrapper threw away:

| Kind | Meaning |
|---|---|
| `NotStarted` | Bootstrap not requested yet. Never show this to a user. |
| `Offline` | No TCP connectivity at all. |
| `Filtering` | TCP works, the Tor handshake does not. **The censorship signature.** |
| `CantReachTor` | Some other problem reaching the network. |
| `ClockSkewed` | Device clock breaks certificate validation. |
| `CantBootstrap` | Directory could not be assembled. |
| `Other` | A kind added upstream after this mapping was written. |

`BlockageKind::suggests_censorship()` is **advisory**. arti describes
`blocked()` as best-effort and warns it "may declare that Arti is stuck for
reasons that are incorrect". Use it to *offer* circumvention; never assert to
the user that they are being censored.

`NotStarted` deserves its own note: it is arti reporting our own deliberate
`BootstrapBehavior::Manual` back to us, and it is present the entire time
between `start()` and `bootstrap()`. `is_user_visible()` exists to filter it.

### The probe is the canary

`ready_for_traffic` means "a request can be started", not "a request
succeeded". `probe()` opens and closes a real circuit through
`TorClient::connect`, bypassing both the SOCKS listener and the app's servers.
That is what separates the two failures the app currently cannot tell apart:

| Probe | RecoverBull | Conclusion |
|---|---|---|
| ok | ok | healthy |
| ok | fails | **the server** — Tor is fine |
| fails | fails | **Tor** — read `blockage` for why |

### SOCKS scope

`CONNECT` to `.onion` hosts only. Clearnet and IP targets are answered with
`NOT_ALLOWED`; the embedded proxy exists for Bull Bitcoin's hidden-service
traffic, not as a general-purpose Tor proxy for other local processes. A
maximum of 64 connections, a 10-second handshake deadline, and a 60-second Tor
connection deadline per session bound local resource use. Session ports are
loopback-only and distinct, but currently unauthenticated; callers must not log
or expose them, and native SOCKS credentials remain future hardening.

`RESOLVE`/`RESOLVE_PTR` are recognized by the protocol parser and answered with
`COMMAND_NOT_SUPPORTED`: nothing in the app uses them, and a subtly wrong
name-resolution path inside an anonymity system is worse than a clean refusal.
`BIND`/`UDP_ASSOCIATE` are rejected by `tor-socksproto` before a request object
exists, so the connection is closed without a SOCKS reply — the same behaviour
as arti's own proxy.

## Testing

```sh
cargo test --all-targets --locked                             # hermetic, no network
cargo test --locked --test live_network -- --ignored --nocapture # real Tor network
cargo clippy --all-targets --locked -- -D warnings
cargo fmt --check
fvm flutter analyze --fatal-warnings --fatal-infos
```

The live suite bootstraps for real, watches progress on the status stream,
runs the probe against a working and a bogus destination, and drives an actual
SOCKS5 `CONNECT` end to end — reading a live HTTP response back through the
tunnel.

## Why this is a standalone package, not part of the rust_bindings aggregate

It was going to be a sub-crate of `rust_lib_bull_sdk`, like `lwk` and `boltz`.
Cargo refuses:

```
package `libsqlite3-sys` links to the native library `sqlite3`, but it
conflicts with a previous package which links to `sqlite3` as well
```

- `ark_wallet` -> `ark-client 0.7.0` -> `sqlx 0.8` -> `libsqlite3-sys 0.30`
- `onion` -> `arti-client 0.47` -> `tor-dirmgr` -> `rusqlite >=0.36 <0.41` ->
  `libsqlite3-sys 0.37`

Only one package in a graph may declare `links = "sqlite3"`. `rusqlite` is a
hard, non-optional dependency of `tor-dirmgr` — no feature turns it off — so
there is no way to make arti fit alongside sqlx 0.8.

This unblocks itself upstream: `sqlx-sqlite 0.9.0` (2026-05-21) accepts
`libsqlite3-sys >=0.30.1 <0.38.0`, which covers 0.34. The day `ark-client`
moves from `sqlx ^0.8` to `^0.9`, the two can share a graph again. Until then
the split is forced, not chosen.

The consolation is that the forced shape is the better one anyway: `onion`
ships its own `.so` (like `bdk_dart` and `payjoin` already do in the app),
keeps its own release profile instead of joining a 661-crate fat-LTO link
unit, and can follow arti's monthly releases without waiting for the
aggregate.

## Snowflake limitations

- The bridge lines are copied verbatim from Tor Browser's
  `projects/tor-expert-bundle/pt_config.json` (re-checked 2026-10-07). Updating
  Arti or IPtProxy requires reviewing these values against the current official
  Snowflake configuration.
- Arti has no BridgeDB/moat client. A future dynamic bridge distribution flow
  would require a separate integration.
- Changing between direct and Snowflake transport recreates the client; it is
  not a live `TorClient::reconfigure()` operation.
- IPtProxy bundles GPL-3.0 Lyrebird even though this package invokes only
  Snowflake. Production distribution requires legal approval and compliance.

## Known upstream hazard

`arti-client` documents that it "can call `exit(1)` and terminate your process
if it receives a network consensus document telling it that it is obsolete"
(tracked as arti issue #1932). For a wallet this is a real operational risk and
an argument for keeping the dependency current.

## Binding shape

Run `./codegen.sh` with flutter_rust_bridge_codegen 2.13.0 to regenerate the complete Dart API and preserve Native Assets loading. Flutter 3.50 / Dart 3.14 loads the registered `package:onion/src/rust/frb_generated.io.dart` code asset; an explicit library override and `initMock` remain available for tests. The Android/iOS plugin still provides the Snowflake platform transport, while Rust builds through Native Assets.

The generated API follows the Rust surface:

```dart
abstract class TorService implements RustOpaqueInterface {
  static Future<TorService> start({required String stateDir,
                                   required String cacheDir,
                                   required int socksPort});
  static Future<TorService> startWithSnowflake({required String stateDir,
                                                 required String cacheDir,
                                                 required int socksPort,
                                                 required int snowflakePort});
  Future<TorSession> openSession({required int socksPort});
  Future<void> bootstrap();
  Future<void> bootstrapWithTimeout({BigInt? timeoutMs});
  Future<TorStatus> status();
  Stream<TorStatus> watchStatus();
  Future<int> probe({required String host, required int port,
                     required int timeoutMs});
  Future<void> setDormant({required bool dormant});
  Future<int> socksPort();
  Future<void> stop();
}

abstract class TorSession implements RustOpaqueInterface {
  Future<int> socksPort();
  Future<bool> proxyIsAlive();
  Future<void> stop();
}
```

`TorStatus` and `Blockage` came out as Dart value classes with `==`/`hashCode`,
`BlockageKind` and `TorFailureKind` as real Dart enums, `TorFailure` as a class
`implements FrbException`, and every doc comment was carried across verbatim.
Rust `snake_case` became Dart `camelCase`; `async fn` became `Future`.
Hand-written Rust binding code: **zero lines**.

The generator is syntactic, not semantic, so four things had to be written in
shapes it recognises. None of them are annotations on business logic; all are
recorded at their call sites:

| Symptom | Cause | Fix |
|---|---|---|
| `TorResult`, `TorResultDuration`, `TorResultSelf` exported as opaque handles | FRB pattern-matches the *written* type; a `type TorResult<T>` alias hides `Result` | spell `Result<T, TorFailure>` out in public signatures |
| `status_stream` skipped with "error during generation" | no mapping for `impl Stream` | add `watch_status(sink: StreamSink<TorStatus>)`; `#[frb(ignore)]` on the Rust-only one |
| `Result<Duration, _>` would not compile | FRB maps `Duration` inbound via chrono but has no outbound conversion | milliseconds as `u32` across the boundary (`u64` would surface as `BigInt`) |
| `mod frb_generated;` injected above the inner attributes | codegen inserts at line 1, which Rust rejects | move it below; its own auto-comment admits the placement "may not be accurate" |

Three annotations total, all justified: `#[frb(ignore)]` on the Rust-only
stream helper, `#[frb(ignore)]` on the `impl Display` error constructors (no FFI
mapping, and they are internal builders), and `#[frb(sync)]` on the three pure
predicates so a `matches!` does not become an async round-trip to the Rust
isolate.

Maintenance consequence: adding a method to `TorService` means writing the Rust
method and re-running the generator. Nothing else.
