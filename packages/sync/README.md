# sync

The single writer of the native BDK and LWK wallet stores: revisions, a cross-isolate lock, a hydrating reader, Electrum sync and the Bitcoin spend gate. The application depends on this package; it never imports `bb_mobile`.

## Public surface

`storage.dart` also exposes `SyncWalletValuesDatasource` for the remaining legacy wallet reader. It reads the existing Sync handles and preserves their snapshot failures; it does not open or write native stores.

`sync.dart` is the entry point. `Sync.foreground` returns `Sync`, which owns the stores and the published values of this isolate; `Sync.background` returns `BackgroundSync`, which only refreshes an existing wallet, reads the revision it last saw and closes. `sync.wallet(key)` returns a `Wallet`: a key and the generation it was obtained for, never a native object. A handle obtained before a delete or a re-import never follows it; its values then read unavailable with `SyncNotFoundFailure`.

Reads are `Observed<T>` values. `now` returns the last value published in this isolate, synchronously, with no IO, native call or mapping. `watch()` emits that value, then each distinct change; a newer revision with identical data is not a change, staleness and generation changes always are. Every value carries its status (`notLoaded`, `ready`, `stale`, `unavailable`, `closed`), its revision and, when relevant, a `SyncFailure`: an unavailable wallet never reads as a zero balance or an empty list.

```dart
final wallet = switch (await sync.wallet(key)) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.logCode),
};
await wallet.load(); // local stores only, latest committed revision
final balances = wallet.balances.now; // same frame as the coins below
final coins = wallet.coins.now;
wallet.history.watch().listen(render);
```

Values are mapped from the native wallet once per revision, built into one immutable frame, then published by a single pointer assignment before any notification: several `now` reads without an `await` between them see the same revision. Who republishes after a commit made elsewhere: the revision reader emits a change whenever a read finds a new state, and the foreground reads after every worker outcome (`WalletNativeRuntime.refresh`); a change for a wallet that has values or subscribers schedules a reload.

Address lists can read wallet.addresses.usage() after loading. The result combines the published history and coin balances, counts each transaction once per paying address, and uses confidential addresses on Liquid. The app adds labels. WalletValue.latest returns the published data or its typed failure. Inspect status and revision when freshness matters.

⚠️ A protocol decision never reads `now`. `wallet.ownership()` (scripts the index derives, revealed plus lookahead, and every output held, spent ones included) and `wallet.unspent()` load the exact committed revision and return `SyncBusyFailure` when the reader can only serve an older one, for instance while the writer holds the store. Payjoin's ownership checks and spendable coins and the Liquid build's coin filter use them. Liquid has no ownership index: LWK does not expose it.

## Native runtime

`package:sync/write.dart` publishes `WalletNativeRuntime.open` for composition. It owns provisioning, recovery and native lifecycle operations on `WalletKey`, returning `Result` values. The catalog remains external through `WalletCatalogPort`; its owner supplies the deletion callback, invoked only after native deletion succeeds. A failed global provisioning pass does not prevent a known wallet from attempting its own read or receive operation.

Every `WalletCatalogPort` read must complete, with either a value or a failure. Catalog reads must never call `Sync.close()` because closing waits for in-flight reads to finish.

`package:sync/inventory.dart` adapts the Secrets inventory to this port. A foreground catalog captures its live grant before each read and discards the result if that grant expires; `captureForeground` binds a read-only port to one explicit grant for callers that must retain that identity across several reads. A background catalog reads only the persisted background grants and does not follow foreground view changes or locking.

For an exact local balance, capture a `RetainedBalanceDemand` for a full `WalletKey` before scheduling work. Its synchronous environment snapshot must be absent during a transition and advance its epoch even when the committed environment is unchanged. `demandRetainedBalance` requires a successfully initialized owner and an existing store and reader lease; it never opens a runtime, provisions, syncs, or retries. It maps only the total, even when the revision has not changed, and returns the exact native revision. Recheck the demand before using that receipt with `readRetainedBalance`: the getter itself only checks the catalogue and native revision, not the environment epoch. `retainedBalanceChanges` is a wake-up signal without data, not a native revision event. Catalogue or environment renewal requires a new explicit demand; no startup or UI consumer is installed by this API.

## Transactions

`transactions.dart` publishes wallet-independent Bitcoin and Liquid transaction values used by signed-transaction review. These provide review projections, while the history types in `sync.dart` describe a wallet’s view of its activity. Import the library for the view you need; neither exposes native handles.

`wallet.tx` holds the native spends, as commands of the single writer: `build(SpendRequest)` (a `BitcoinSpendRequest` or a `LiquidSpendRequest`), `bump(BumpFeeRequest)` and `consolidate(ConsolidationRequest)` return an `UnsignedSpend` (or a list of them) carrying the wallet's revision and generation, the encoded PSBT or PSET and its effective inputs. Each command runs one order: guard and generation admission, writer lock, durable intent, a native wallet opened fresh from its store, freezes and reservations read, one build, a check of the effective inputs, outputs, network and owner, persistence of the native changes, a refused build included, native close, release, hand-out. No native wallet outlives its command, so abandoned previews and bumps reveal no new change index; a persistence failure never hands a transaction out. Failures are `SyncSpendFailure`s (`SyncSpendBlockedFailure`, `SyncProtectedInputsFailure`, `SyncInsufficientFundsFailure`, …), `SyncBusyFailure` or `SyncStorageFailure`.

`wallet.tx.prepareFunding(BitcoinSpendRequest, context:)` is the protocol-neutral funding path. It requires a `SpendOwner` and the optional `fundingReservations:` port configured on `Sync.foreground`; absence is a typed refusal. The source must use BIP84 native-segwit receive and change, and the actual PSBT must remain unsigned and unfinalised with P2WPKH witness prevouts. Selected-only requests are checked against the effective inputs. The one BitcoinSpendGate admission already owns the WriterLock: preparation reuses that lease and holds the freeze guard through native build/persist, revision completion and durable reservation, then checks the combined reservations again before handing out the PSBT. No timeout releases a pending reservation call; close waits for it. An interrupted native intent or unavailable gate refuses preparation until host sync/recovery has restored readiness.

`FundingReservationPort` belongs to the host protocol. It atomically stores the operation, owner, generation, exact PSBT/txid/context and effective input ownership; idempotence applies to an identical owner, transaction and context, and conflicts are refused. This does not promise that repeated `prepareFunding` requests rebuild identical bytes. After an uncertain outcome, recovery reads the exact PSBT from the host journal instead of building a replacement. Its read authority is combined inside sync with the ordinary reservation provider for every build and broadcast. Neither callback may reenter Sync, a wallet facade or the freeze queue. The host journals requested funding before calling; any failure may follow an uncertain reservation commit and requires reconciliation before releasing an obligation. Native and reservation persistence are separate commits: a reservation refusal may leave harmless durable change-index advancement, but never returns prepared funding. A late cross-protocol hold refuses hand-out while preserving both obligations. Signing and later guarded broadcast retain the same owner and generation, after all source-wallet locks have been released. Context is public recovery metadata bounded to 4096 UTF-8 bytes; key material must never be passed.

Signing stays with the caller, through `secrets` or a hardware signer, with no lock held. `wallet.tx.broadcast(SignedSpend)` checks the generation again, reads the freezes and reservations again in the freeze queue, refuses a protected input, then sends through the owner's `WalletConnectionPort`. Bitcoin keeps the guard from admission to the receipt; `SpendReceipt.durable` says whether the guard recorded it, and a non-durable receipt keeps refusing spends in this process. Build a `SignedSpend` with `unsigned.signed(...)`, or with `wallet.tx.signed(...)` for a transaction signed in an earlier run (a Payjoin proposal, a saved payment), which takes the handle's generation. `readiness` publishes the guard's last verdict without IO: the first demand schedules it, and it is asked again, outside `now`, after every revision of the wallet committed or read in this isolate, so a sync that observes a pending spend makes it `ready` without a `check()`. It is never a permission: build and broadcast check again. `check()` asks the guard now. `originalSignatures(txid)`, `annotate(psbt)` and `liquidEffect(pset)` are the read-only commands builders and Payjoin need.

⚠️ Exclusions only narrow what sync may spend. Freezes and other sessions' reservations are always excluded, and the effective inputs of every build, bump and consolidation batch are checked against them; a `SpendOwner` may spend the inputs its own session reserved for this wallet, and a bump only its original's. A freeze is never exempted. Liquid has no spend guard: its receipts say `guarded: false`, and only freezes are checked at its broadcast.

⚠️ Consolidation batches drain to successive unused addresses with no durable reservation: two rounds before a sync can reuse an address, and a partial broadcast of more batches than the gap limit is not proven recoverable.

## Background

`Sync.background` opens existing stores only and throws while the foreground has not created them or quarantined metadata awaits adoption. `BackgroundSync` exposes three operations. `refresh(key)` synchronizes an existing store with discovery and the initial scan fixed to false; `collectIncoming` stays so the background job can announce incoming payments. `revision(key).now` returns the revision state this isolate last read, without IO: `notLoaded` until a first demand has read it, `stale` after a failed sync, `closed` once closed; every refresh republishes it. It has no wallet handle, address, freeze or spend: those stay in the foreground.

## Coin freezes

Sync reads and changes user freezes; the app keeps them in its published `frozen_utxos` table (schema v15) and serves it through the mandatory `FreezeStorePort` given to `Sync.foreground`. Sync keeps no freeze store or copy of its own and is the table's only writer, from the foreground; the background never reads it. `wallet.coins.now` and `.watch()` publish each coin with its `frozen` state, republished after every change without remapping the wallet; until a first read succeeds the coins read unavailable with the store's failure, never unfrozen. `wallet.coins.freeze(outpoint)` and `unfreeze(outpoint)` commit through the port and return a `PolicyRevision` counted by this isolate; a handle ended by a delete or a re-import is refused. A freeze is global by outpoint: its origin only attributes it for BIP329 export, and an unfreeze removes every attribution. `sync.coins` does the same without a wallet, for BIP329 imports and exports: `freeze(outpoint, origin:)` keeps the origin as given, empty included, and `listFrozen()` returns every attribution. `wallet.unspent()` reads the freezes from the store.

⚠️ A store that cannot answer is an `Err`, never an empty list. Spend construction checks its effective inputs against `FreezeAuthority.forbiddenInputs()`, or `guard()`, which reads the freezes and runs the check in the queue every freeze and unfreeze goes through, so none commits meanwhile: sync is the table's only writer, from the foreground, so that queue suffices. A failed read never runs the check.

Library functions open no wallet and create no store:

- Codecs. `decodeBitcoinTransaction` and `decodeBitcoinPsbt` are synchronous for Payjoin's stream transforms and throw a `FormatException` on refusal; `canonicalBitcoinPsbt`, `finalizeBitcoinPsbts` (combine a signer's trimmed reply with the PSBT it was given, then finalize), `parseBitcoinAddress`, `bitcoinScriptAddress`, `bitcoinAddressScript`, `decodeLiquidTransaction`, `decodeLiquidPset`, `liquidAddressNetwork` and `validateAddress` return a `SyncChainFailure` or another `SyncFailure`. Input is bounded before it reaches a native parser, and a Liquid amount the transaction keeps confidential stays `null`, never zero.
- PSBT evidence. `inspectBitcoinPsbt` returns immutable ordered prevouts, values/scripts, fee, outputs, partial ECDSA/taproot signature flags and exact final fields. Missing or contradictory UTXOs refuse; nonwitness parents must match the input txid/vout. `finalTransaction` is present only when every input has a final field (empty included), and is structural extraction, never proof of script validity or chain UTXO authenticity. A partial-signed PSBT can have no final transaction: unsigned-funding consumers must reject signature flags and any final field explicitly. Hosts verifying another raw transaction must compare every consensus byte, witnesses included, with `finalTransaction.bytes`; txid equality alone does not bind witness data. Existing parser/transaction size limits and checked native final extraction apply. No wallet is opened.
- Chain access. `broadcastBitcoinTransaction` and `broadcastLiquidTransaction` go through the servers the owner's `WalletConnectionPort` selects; `broadcastBitcoinTransactionTo`, `bitcoinTransactionKnown`, `probeBitcoinServer` and `estimateBitcoinFees` take the one `WalletConnection` a caller running its own fallback hands them. Native errors and the servers' replies are reduced here to rejected, already in chain, connection or unknown outcome, never kept as text. Across servers a single cause is reported only when every server agreed: a retry after an uncertain attempt is never read as a rejection, and nothing is retried once the servers are exhausted. These functions do not admit a spend: a wallet's spend goes through `wallet.tx.broadcast`.
- Wallet-free reads. `bitcoinPsbtFee`, `liquidPsetFees`, `bitcoinPublicDescriptor` (an account key's descriptor with its origin) and `isLiquidStatusConflict`; `prescanBitcoinWallet` full-scans a wallet not yet imported in an in-memory wallet, in an isolate of its own.

`Sync.foreground` requires an `InputReservationPort`. Payjoin owns its input reservations and serves each with its session, wallet, network and state; sync reads them to check the inputs of a spend. A failed read is an `Err`, never an empty list.

The runtime's foreground store getter is internal to Sync. Ark uses `withBitcoinRevisionAdmission` for a durable callback under the normal spend lease: it gets only the admitted revision, and the lease closes before the call returns. It must not reenter Sync, sign, use the network or detach work. `readReservedOutpointsForDisplay` snapshots combined reservations; a null value means unknown, not empty. Terminal runtime close refuses both operations and waits for those already admitted. Neither is mounted in the foreground revision proof.

Still transitional: `write.dart` builds the writer, the spend gate and the Electrum engine. Other consumers still obtain `Sync` for wallet and freeze capabilities. The background job opens `ExistingStores` and an `ElectrumSync` through it, not `BackgroundSync`. No native handle is lent: outside this package, only `secrets` uses BDK and LWK. `diagnostics.dart` publishes the identifier-free lease diagnostic context. `testing.dart` builds real `Wallet`s for consumers' tests.

<!-- sync-api:start -->

Generated from `lib/sync.dart`; update with `make sync-api-docs`.

Each asynchronous `Future<Result<T, SyncFailure>>` is shown as `T`. Other returns are unchanged. `name:` denotes a required named argument; brackets denote optional arguments and show explicit defaults. Constructors, static members other than the entry points marked `static`, Object methods and internal members are omitted. Synchronous capability groups are expanded; data and widget values remain leaves.

```text
Sync
|-- static foreground(documentsDirectory:, catalog:, reservedAddresses:, freezes:, inputReservations:, [fundingReservations:], connections:) -> Sync
|-- static background(documentsDirectory:, catalog:, connections:) -> BackgroundSync
|-- wallet(key) -> Wallet
|-- changes
|   `-- watch() -> Stream<WalletRevisionState>
|-- recovery
|   |-- pending -> Observed<bool>
|   `-- complete() -> Result<void, SyncFailure>
|-- coins
|   |-- listFrozen() -> List<FrozenOutpoint>
|   |-- freeze(outpoint, origin:) -> PolicyRevision
|   `-- unfreeze(outpoint) -> PolicyRevision
`-- close() -> Future<void>
```

```text
Wallet
|-- key -> WalletKey
|-- generation -> int
|-- tx
|   |-- build(request) -> UnsignedSpend
|   |-- prepareFunding(request, context:) -> UnsignedSpend
|   |-- bump(request) -> UnsignedSpend
|   |-- consolidate(request) -> List<UnsignedSpend>
|   |-- broadcast(spend) -> SpendReceipt
|   |-- signed(transaction, [owner:], [replacing:]) -> SignedSpend
|   |-- readiness -> Observed<WalletValue<BitcoinSpendStatus>>
|   |-- check([replacing:]) -> BitcoinSpendStatus
|   |-- originalSignatures(txid) -> SignatureCheck
|   |-- annotate(psbt) -> String
|   |-- liquidAmountToAddress(pset, address) -> BigInt
|   `-- liquidEffect(pset) -> LiquidPsetEffect
|-- balances -> Observed<WalletValue<Balances>>
|-- coins
|   |-- now -> WalletCoins
|   |-- watch() -> Stream<WalletValue<CoinList>>
|   |-- freeze(outpoint) -> PolicyRevision
|   `-- unfreeze(outpoint) -> PolicyRevision
|-- history -> Observed<WalletValue<ChainTransactionList>>
|-- addresses
|   |-- book -> Observed<WalletValue<AddressBook>>
|   |-- at(index, [keychain: Keychain.external]) -> Observed<WalletValue<DerivedAddress>>
|   |-- usage() -> Result<Map<String, ({BigInt balanceSat, int transactionCount})>, SyncFailure>
|   `-- owns
|       |-- script(script) -> Observed<WalletValue<Ownership>>
|       `-- outpoint(outpoint) -> Observed<WalletValue<Ownership>>
|-- load() -> WalletRevision
|-- ownership() -> OwnershipIndex
|-- unspent() -> CoinList
|-- readExactOwnership() -> OwnershipIndex
`-- readExactUnspent() -> CoinList
```

```text
BackgroundSync
|-- refresh(key, [collectIncoming: false]) -> SyncCompletion
|-- revision(key) -> BackgroundRevision
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
lib/src/data/freeze_authority.dart  freezes through the app's port: reads, commands, forbidden inputs, guard
lib/src/data/write/        every native store mutation: writer session, lock, spend gate
lib/src/data/write/spend/  native spends: one fresh wallet per command, input checks, broadcast
lib/src/data/write/datasources/  BDK wallet store, LWK wallet store, BDK Electrum client, parents cache
lib/src/data/write/sync/   Electrum engine and its Bitcoin and Liquid passes
lib/src/data/read/         reader: hydration under admission, frame mapping, never a mutation
lib/src/data/wallet_projections.dart  published frames, Observed values, exact queries
lib/src/public/            Sync, Wallet, BackgroundSync and their groups
```

Shared code never imports `data/write`, and `data/read` never does. `make native-write-check` enforces the boundary on symbols: native store mutations only under `lib/src/data/write/`, hydration only under `lib/src/data/read/`. It also enforces native import ownership: outside this package, only the files in `tool/native_import_allowlist.dart` may use BDK or LWK, and a listed file that stops must leave the list, so the list only shrinks.

## Stores

`<docs>/<hexId>_bdk_dart` and `<docs>/<hexId>` are the published native stores; their paths and content are unchanged (`nativeWalletStoragePath`, UTF-16 hex id). The package's own stores live in `<docs>/transaction_sync/`: `revisions.sqlite` (a `.recovery` marker while quarantined metadata awaits adoption), `spend_gate.sqlite` (a `.provisioned` marker so a lost gate is never recreated empty) and `locks/`, one lock per native store, named after its path, so two keys resolving to one store share one lock. Each SQLite store is created by one complete `CREATE` with `user_version`; an existing store at another version is refused, not migrated. Unreadable or foreign revision metadata is quarantined by `Sync.foreground`: only existing native stores are adopted, and no Bitcoin spend is admitted until `sync.recovery.complete()` has invalidated every retained obligation and removed the marker.

Bitcoin broadcast acceptance records the exact spent outpoints decoded from the transaction actually sent, for both raw transactions and PSBTs. The obligation and inputs share one SQLite write; a failed write retains an immutable copy for retry in the same process. A non-durable receipt does not promise survival of process death. The journal contains no PSBT, signatures or transaction bytes. An existing row only acquires inputs if its stored inputs are SQL NULL; replay does not overwrite known evidence, generation or observation state.

An accepted transaction missing from the canonical wallet is settled only by a canonical **confirmed** transaction spending one of its known outpoints. An unconfirmed replacement, including a tracked RBF broadcast by Bull, does not settle the absent original: ordinary wallet spends and a second fee bump remain blocked until confirmation (or positive observation of the original). Every later pass must prove the conflict again, so a reorganization restores the barrier. Legacy rows and current txid-only Payjoin handoffs may have unknown inputs; they remain blocked when the original is absent. A positive observation of the original can recover those inputs. Server omission, elapsed time and recovery never mean cancellation.

## Writer

`WriterSession` (`data/write/writer_session.dart`) holds the one safety sequence: lock, generation and descriptor hash, resume of an interrupted intent, durable intent, native mutation, spend evidence, revision, release. The lock is held through actual native completion, never released by a timer, and no mutation is retried. The app enters through `NativeWalletWriterRepository`, which resolves descriptors from the catalog and checks address reservations; the sync worker enters with the descriptor it received, adopts an existing store in the foreground under the same lock acquisition as the sync that follows, and resumes interrupted intents there only. The lock is a SQLite `BEGIN IMMEDIATE` with `busy_timeout = 0`; writers retry for up to one second, readers never wait and serve a stale snapshot instead.

## Electrum sync

`ElectrumSync.execute` opens existing stores only, in a compute worker. Every non-targeted Bitcoin pass first queries the revealed scripts; at checkpoint height zero or on explicit discovery it then full-scans. The pass applies both updates and persists once; spend evidence is reported only after that persist. The parents cache prefills the client and is best effort. The pinned bdk_chain full scan counts the stop gap from index 0, so it never replaces revealed-script coverage. Only connection establishment, before a store is opened, may fall back to another server. A routine request for the same wallet joins a routine pass already running, a queued discovery and any request the active pass cannot answer run after it, and anything other than an `Exception` thrown during a pass reaches every waiting caller. Incoming payment ids are collected only with `collectIncoming`.

A targeted pass (`ElectrumSync.execute` with `targets`, `ForegroundWalletSynchronization.executeTargeted`) queries only the revealed wallet indices its targets pay or spend, applies and persists once, and skips the routine revealed-script and full-scan queries. Its completion reports conclusive answers only: a queried target with ambiguous evidence still stays unknown. A targeted pass never initializes or scans a wallet, so a wallet without an initial scan fails `SyncInitialScanRequiredFailure`, and a non-Bitcoin wallet rejects targets with `SyncUnsupportedNetworkFailure` instead of running a routine sync. Targeted requests merge into a targeted pass that has not started, a later one gets its own pass, and a routine refresh is never satisfied by a targeted pass.

⚠️ Liquid never goes through Tor: the pinned LWK has no SOCKS option, so the connection policy drops the proxy for Liquid and both the probe and the LWK sync connect directly.

## Native test suites

`native_test/lwk_worker_test.dart` is a separate native integration suite because rust_bindings' Rust shared library is not built by the BDK asset hook used by ordinary Flutter unit tests. Supply the host library built from the pinned SDK (its own locked Cargo build and pinned toolchain), then run on Linux:

```sh
LD_LIBRARY_PATH="$RUST_BINDINGS_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" fvm flutter test packages/sync/native_test/lwk_worker_test.dart
```

This test has no skip and uses only the published BIP39 vector plus loopback traffic. It verifies real LWK initialization in the worker, fallback before opening, and no retry after opening when a Bitcoin-only fixture rejects Liquid synchronization. It does not establish successful live Liquid synchronization or device lock safety. The compute worker calling BullSdk.init() has not been validated on a phone; that device gate remains open. Normal `make checks` covers `test/`; run this additional suite when changing the native Liquid path.

## Bitcoin regtest host test

The explicit native suite exercises offline writer creation, bcrt1 receive, Nigiri faucet funding, writer-owned discovery, native reader hydration, an explicit-fee signed broadcast, sync/history, fresh-reader reopening and headless sync. It uses the published BIP39 test vector and disposable native stores. Start a disposable Nigiri service separately; the test never starts or reconfigures it. From this package directory:

```sh
fvm flutter test --no-pub native_test/native_regtest_nigiri_test.dart
```

The defaults are the local development Electrum port 50000 and faucet port 3000. Override with `--dart-define=NIGIRI_ELECTRUM=...` and `--dart-define=NIGIRI_FAUCET=...`. Ordinary unit checks do not require this service. This native test does not validate app navigation, wallet import or mobile lifecycle behavior.

`validateAddress(address, network)` serves payment consumers. It validates against captured concrete network context (Liquid mainnet, testnet and regtest each accept only their own addresses), rejects signet, and limits Bitcoin regtest destinations to the distinct bcrt1 witness encoding. Bitcoin testnet Base58 remains accepted; address bytes cannot distinguish its provenance from regtest. This is destination authorization, not URI parsing or an Electrum genesis check. Liquid validation goes through LWK, so its cases are in the native suite: `LD_LIBRARY_PATH="$RUST_BINDINGS_LIB_DIR" fvm flutter test native_test/validate_liquid_address_test.dart`.

The Liquid codecs' refusals of hostile input through the real LWK parser are in `native_test/liquid_codec_test.dart`, run the same way; the unit suite covers their mapping with a fake binding.

Spend preparation consumers resolve a `WalletKey` and call the Result-returning `wallet.tx` capability directly. App repositories keep metadata, fee and presentation conversions; the former BDK/LWK forwarding datasources are removed. `bitcoinRecipientAmounts` owns PSBT recipient-script matching and remainder calculation in sync.

## Persisted wallet sync times

The storage library imports the historical sync time for each wallet id into Sync's encrypted metadata store. It preserves the original nullable value through the migration. The native revision and writer lease stores continue to coordinate wallet operations.

## Dependencies

- `secrets` supplies authorized wallet descriptors to the foreground inventory projection; Sync turns them into native catalog entries.
