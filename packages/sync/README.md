# sync

The single writer of the native BDK and LWK wallet stores: revisions, a cross-isolate lock, a hydrating reader, Electrum sync and the Bitcoin spend gate. The application depends on this package; it never imports `bb_mobile`.

## Public surface

`sync.dart` is the entry point. `Sync.openForeground` returns `Sync`, which owns the stores and the published values of this isolate; `Sync.openExisting` returns `HeadlessSync`, which only refreshes an existing wallet and closes. `sync.wallet(key)` returns a `Wallet`: a key and the generation it was obtained for, never a native object. A handle obtained before a delete or a re-import never follows it; its values then read unavailable with `SyncNotFoundFailure`.

Reads are `Observed<T>` values. `now` returns the last value published in this isolate, synchronously, with no IO, native call or mapping. `watch()` emits that value, then each distinct change; a newer revision with identical data is not a change, staleness and generation changes always are. Every value carries its status (`notLoaded`, `ready`, `stale`, `unavailable`, `closed`), its revision and, when relevant, a `SyncFailure`: an unavailable wallet never reads as a zero balance or an empty list.

```dart
final wallet = switch (await sync.wallet(key)) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.logCode),
};
await wallet.load(); // local stores only, latest committed revision
final balances = wallet.balances.now; // same frame as the coins below
final coins = wallet.coins.now;
wallet.transactions.watch().listen(render);
```

Values are mapped from the native wallet once per revision, built into one immutable frame, then published by a single pointer assignment before any notification: several `now` reads without an `await` between them see the same revision. Who republishes after a commit made elsewhere: the revision reader emits a change whenever a read finds a new state, and the foreground reads after every worker outcome (`WalletNativeRuntime.refresh`); a change for a wallet that has values or subscribers schedules a reload.

⚠️ A protocol decision never reads `now`. `wallet.ownership()` (scripts the index derives, revealed plus lookahead, and every output held, spent ones included) and `wallet.unspent()` load the exact committed revision and return `SyncBusyFailure` when the reader can only serve an older one, for instance while the writer holds the store. Payjoin's ownership checks and spendable coins and the Liquid build's coin filter use them. Liquid has no ownership index: LWK does not expose it.

Library functions open no wallet and create no store:

- Codecs. `decodeBitcoinTransaction` and `decodeBitcoinPsbt` are synchronous for Payjoin's stream transforms and throw a `FormatException` on refusal; `canonicalBitcoinPsbt`, `finalizeBitcoinPsbts` (combine a signer's trimmed reply with the PSBT it was given, then finalize), `parseBitcoinAddress`, `bitcoinScriptAddress`, `bitcoinAddressScript`, `decodeLiquidTransaction`, `decodeLiquidPset`, `liquidAddressNetwork` and `validateAddress` return a `SyncChainFailure` or another `SyncFailure`. Input is bounded before it reaches a native parser, and a Liquid amount the transaction keeps confidential stays `null`, never zero.
- Chain access. `broadcastBitcoinTransaction` and `broadcastLiquidTransaction` go through the servers the owner's `WalletConnectionPort` selects; `broadcastBitcoinTransactionTo`, `bitcoinTransactionKnown`, `probeBitcoinServer` and `estimateBitcoinFees` take the one `WalletConnection` a caller running its own fallback hands them. Native errors and the servers' replies are reduced here to rejected, already in chain, connection or unknown outcome, never kept as text. Across servers a single cause is reported only when every server agreed: a retry after an uncertain attempt is never read as a rejection, and nothing is retried once the servers are exhausted. These functions do not admit a spend: a wallet broadcast still goes through the Bitcoin spend gate in its caller, and Liquid has none.

Still transitional, removed in phase 2: `write.dart` builds the writer, the spend gate and the Electrum engine, and its `SyncForegroundStores` extension hands the app the writer and the borrowed reader; `read.dart` publishes `WalletSnapshotReader`, which lends the shared `bdk.Wallet` or `lwk.Wallet` to the transaction builders only. Callers must not mutate, persist or dispose it. `diagnostics.dart` publishes the identifier-free lease diagnostic context. `testing.dart` builds real `Wallet`s for consumers' tests.

<!-- sync-api:start -->

Generated from `lib/sync.dart`; update with `make sync-api-docs`.

Each asynchronous `Future<Result<T, SyncFailure>>` is shown as `T`. Other returns are unchanged. `name:` denotes a required named argument; brackets denote optional arguments and show explicit defaults. Constructors, static members other than the entry points marked `static`, Object methods and internal members are omitted. Synchronous capability groups are expanded; data and widget values remain leaves.

```text
Sync
|-- static openForeground(documentsDirectory:, catalog:, reservedAddresses:) -> Sync
|-- static openExisting(documentsDirectory:, catalog:, connections:) -> HeadlessSync
|-- wallet(key) -> Wallet
|-- changes
|   `-- watch() -> Stream<WalletRevisionState>
|-- recovery
|   |-- pending -> Observed<bool>
|   `-- complete() -> Result<void, SyncFailure>
`-- close() -> Future<void>
```

```text
Wallet
|-- key -> WalletKey
|-- generation -> int
|-- balances -> Observed<WalletValue<Balances>>
|-- coins -> Observed<WalletValue<CoinList>>
|-- transactions -> Observed<WalletValue<ChainTransactionList>>
|-- addresses
|   |-- current -> Observed<WalletValue<AddressBook>>
|   |-- at(index, [keychain: Keychain.external]) -> Observed<WalletValue<DerivedAddress>>
|   `-- owns
|       |-- script(script) -> Observed<WalletValue<Ownership>>
|       `-- outpoint(outpoint) -> Observed<WalletValue<Ownership>>
|-- load() -> WalletRevision
|-- ownership() -> OwnershipIndex
`-- unspent() -> CoinList
```

```text
HeadlessSync
|-- refresh(key, [collectIncoming: false]) -> SyncCompletion
`-- close() -> Future<void>
```

<!-- sync-api:end -->

These trees are generated from the exports of `lib/sync.dart`; `make sync-api-docs-check` detects stale trees in `make checks`.

## Layout

```
lib/src/domain/            values, failures, repositories/, ports/ (no SDK)
lib/src/data/              paths, store identity, txid parsing, Bitcoin decoder, diagnostics, revision reader
lib/src/data/codec/        wallet-free PSBT, address and Liquid codecs
lib/src/data/chain/        Electrum broadcasts, lookups, probes and fee estimates; broadcast reply classification
lib/src/data/datasources/  SQLite revision store and spend gate, shared by read and write
lib/src/data/write/        every native store mutation: writer session, lock, spend gate
lib/src/data/write/datasources/  BDK wallet store, LWK wallet store, BDK Electrum client, parents cache
lib/src/data/write/sync/   Electrum engine and its Bitcoin and Liquid passes
lib/src/data/read/         reader: hydration under admission, frame mapping, never a mutation
lib/src/data/wallet_projections.dart  published frames, Observed values, exact queries
lib/src/public/            Sync, Wallet, HeadlessSync and their groups
```

Shared code never imports `data/write`, and `data/read` never does. `make native-write-check` enforces the boundary on symbols: native store mutations only under `lib/src/data/write/`, hydration only under `lib/src/data/read/`. It also enforces native import ownership: outside this package, only the files in `tool/native_import_allowlist.dart` may use BDK or LWK, and a listed file that stops must leave the list, so the list only shrinks.

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
LD_LIBRARY_PATH="$BULL_SDK_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" fvm flutter test packages/sync/native_test/lwk_worker_test.dart
```

This test has no skip and uses only the published BIP39 vector plus loopback traffic. It verifies real LWK initialization in the worker, fallback before opening, and no retry after opening when a Bitcoin-only fixture rejects Liquid synchronization. It does not establish successful live Liquid synchronization or device lock safety. The compute worker calling BullSdk.init() has not been validated on a phone; that device gate remains open. Normal `make checks` covers `test/`; run this additional suite when changing the native Liquid path.

## Bitcoin regtest host test

The explicit native suite exercises offline writer creation, bcrt1 receive, Nigiri faucet funding, writer-owned discovery, native reader hydration, an explicit-fee signed broadcast, sync/history, fresh-reader reopening and headless sync. It uses the published BIP39 test vector and disposable native stores. Start a disposable Nigiri service separately; the test never starts or reconfigures it. From this package directory:

```sh
fvm flutter test --no-pub native_test/native_regtest_nigiri_test.dart
```

The defaults are the local development Electrum port 50000 and faucet port 3000. Override with `--dart-define=NIGIRI_ELECTRUM=...` and `--dart-define=NIGIRI_FAUCET=...`. Ordinary unit checks do not require this service. This native test does not validate app navigation, wallet import or mobile lifecycle behavior.

`read.dart` also publishes `validateAddress(address, network)` for payment consumers. It validates against captured concrete network context (Liquid mainnet, testnet and regtest each accept only their own addresses), rejects signet, and limits Bitcoin regtest destinations to the distinct bcrt1 witness encoding. Bitcoin testnet Base58 remains accepted; address bytes cannot distinguish its provenance from regtest. This is destination authorization, not URI parsing or an Electrum genesis check. Liquid validation goes through LWK, so its cases are in the native suite: `LD_LIBRARY_PATH="$BULL_SDK_LIB_DIR" fvm flutter test native_test/validate_liquid_address_test.dart`.

The Liquid codecs' refusals of hostile input through the real LWK parser are in `native_test/liquid_codec_test.dart`, run the same way; the unit suite covers their mapping with a fake binding.
