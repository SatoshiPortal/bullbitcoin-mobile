# transaction_sync

The single writer of the native BDK and LWK wallet stores: revisions, a cross-isolate lock, a hydrating reader, Electrum sync and the Bitcoin spend gate. The application depends on this package; it never imports `bb_mobile`.

## Public surface

- `transaction_sync.dart` is neutral: domain values (`WalletKey`, revisions, `SyncCompletion`, `BitcoinSpendStatus`, `BitcoinBroadcastReceipt`, failures), the transaction id helpers, the `WalletWriterRepository` contract and the `*Port` interfaces the app implements.
- `write.dart` builds everything. The foreground calls `openForeground()`, which creates the revision store and the spend gate before any pass, and gets the writer repository, the revision reader, the snapshot reader, the spend gate, `recoveredMetadata` and `completeRecovery()`. Background code calls `openExisting()`, which never creates or migrates a store. It also exports `ElectrumSync`, the sync engine. No datasource is exported.
- `read.dart` publishes `WalletSnapshotReader`, which lends native handles: `WalletReadSnapshot.wallet` and `borrowedHandle` return the shared `bdk.Wallet` or `lwk.Wallet` itself. Callers must not mutate, persist or dispose it. It also publishes `validateAddress`.
- `diagnostics.dart` publishes the identifier-free lease diagnostic context.

## Layout

```
lib/src/domain/            values, failures, repositories/, ports/ (no SDK)
lib/src/data/              paths, store identity, txid parsing, diagnostics, revision reader
lib/src/data/datasources/  SQLite revision store and spend gate, shared by read and write
lib/src/data/write/        every native store mutation: writer session, lock, spend gate
lib/src/data/write/datasources/  BDK wallet store, LWK wallet store, BDK Electrum client, parents cache
lib/src/data/write/sync/   Electrum engine and its Bitcoin and Liquid passes
lib/src/data/read/         reader: hydration under admission, never a mutation
```

Shared code never imports `data/write`, and `data/read` never does. `make native-write-check` enforces the boundary on symbols: native store mutations only under `lib/src/data/write/`, hydration only under `lib/src/data/read/`.

## Stores

`<docs>/<hexId>_bdk_dart` and `<docs>/<hexId>` are the published native stores; their paths and content are unchanged (`nativeWalletStoragePath`, UTF-16 hex id). The package's own stores live in `<docs>/transaction_sync/`: `revisions.sqlite` (a `.recovery` marker while quarantined metadata awaits adoption), `spend_gate.sqlite` (a `.provisioned` marker so a lost gate is never recreated empty) and `locks/`, one lock per native store, named after its path, so two keys resolving to one store share one lock. Each SQLite store is created by one complete `CREATE` with `user_version`; an existing store at another version is refused, not migrated. Unreadable or foreign revision metadata is quarantined by `openForeground()`: only existing native stores are adopted, and no Bitcoin spend is admitted until `completeRecovery()` has invalidated every retained obligation and removed the marker.

## Writer

`WriterSession` (`data/write/writer_session.dart`) holds the one safety sequence: lock, generation and descriptor hash, resume of an interrupted intent, durable intent, native mutation, spend evidence, revision, release. The lock is held through actual native completion, never released by a timer, and no mutation is retried. The app enters through `NativeWalletWriterRepository`, which resolves descriptors from the catalog and checks address reservations; the sync worker enters with the descriptor it received, adopts an existing store in the foreground under the same lock acquisition as the sync that follows, and resumes interrupted intents there only. The lock is a SQLite `BEGIN IMMEDIATE` with `busy_timeout = 0`; writers retry for up to one second, readers never wait and serve a stale snapshot instead.

## Electrum sync

`ElectrumSync.execute` opens existing stores only, in a compute worker. Every Bitcoin pass first queries the revealed scripts; at checkpoint height zero or on explicit discovery it then full-scans. The pass applies both updates and persists once; spend evidence is reported only after that persist. The parents cache prefills the client and is best effort. The pinned bdk_chain full scan counts the stop gap from index 0, so it never replaces revealed-script coverage. Only connection establishment, before a store is opened, may fall back to another server. Requests for the same wallet share one pass, a queued discovery still runs, and anything other than an `Exception` thrown during a pass reaches every waiting caller. Incoming payment ids are collected only with `collectIncoming`.

⚠️ Liquid never goes through Tor: the pinned LWK has no SOCKS option, so the connection policy drops the proxy for Liquid and both the probe and the LWK sync connect directly.

## Native test suites

`native_test/lwk_worker_test.dart` is a separate native integration suite because bull_sdk's Rust shared library is not built by the BDK asset hook used by ordinary Flutter unit tests. Supply the host library built from the pinned SDK (its own locked Cargo build and pinned toolchain), then run on Linux:

```sh
LD_LIBRARY_PATH="$BULL_SDK_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" fvm flutter test packages/transaction_sync/native_test/lwk_worker_test.dart
```

This test has no skip and uses only the published BIP39 vector plus loopback traffic. It verifies real LWK initialization in the worker, fallback before opening, and no retry after opening when a Bitcoin-only fixture rejects Liquid synchronization. It does not establish successful live Liquid synchronization or device lock safety. The compute worker calling BullSdk.init() has not been validated on a phone; that device gate remains open. Normal `make checks` covers `test/`; run this additional suite when changing the native Liquid path.

## Bitcoin regtest host test

The explicit native suite exercises offline writer creation, bcrt1 receive, Nigiri faucet funding, writer-owned discovery, native reader hydration, an explicit-fee signed broadcast, sync/history, fresh-reader reopening and headless sync. It uses the published BIP39 test vector and disposable native stores. Start a disposable Nigiri service separately; the test never starts or reconfigures it. From this package directory:

```sh
fvm flutter test --no-pub native_test/native_regtest_nigiri_test.dart
```

The defaults are the local development Electrum port 50000 and faucet port 3000. Override with `--dart-define=NIGIRI_ELECTRUM=...` and `--dart-define=NIGIRI_FAUCET=...`. Ordinary unit checks do not require this service. This native test does not validate app navigation, wallet import or mobile lifecycle behavior.

`read.dart` also publishes `validateAddress(address, network)` for payment consumers. It validates against captured concrete network context (Liquid mainnet, testnet and regtest each accept only their own addresses), rejects signet, and limits Bitcoin regtest destinations to the distinct bcrt1 witness encoding. Bitcoin testnet Base58 remains accepted; address bytes cannot distinguish its provenance from regtest. This is destination authorization, not URI parsing or an Electrum genesis check. Liquid validation goes through LWK, so its cases are in the native suite: `LD_LIBRARY_PATH="$BULL_SDK_LIB_DIR" fvm flutter test native_test/validate_liquid_address_test.dart`.
