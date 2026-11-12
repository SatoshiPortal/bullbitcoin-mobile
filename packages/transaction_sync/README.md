# transaction_sync

The native wallet writer, revision store, reader admission and Electrum sync operation. The application depends on this package; this package never imports `bb_mobile`. Flutter is required by bull_sdk and isolate execution; no SDK handles cross the public API.

`WalletKey` is the wallet id plus a primitives network. Engine, endpoint and tuning changes do not change identity. `nativeWalletStoragePath` preserves the legacy UTF-16 hex id and exact BDK suffix/LWK root; it performs no IO. Readers and writers share this path function. Callers pass `getApplicationDocumentsDirectory().path` verbatim. Signet/regtest throw `ArgumentError`: their legacy origins share testnet coin type 1, so enabling them requires catalog uniqueness and a storage migration first.

`WalletConnectionPolicy` owns connection selection through its app implementation. Its callback runs within the existing Electrum policy's scoped Tor route. Only the caller knows whether mutation has started; `mayRetry` must refuse fallback after that point. Exhausted fallback returns the caller's last typed failure; failures before any callback result map to `TransactionSyncConnectionFailure`. Connection values must not escape the callback's lifetime. The labels owner retains the existing system-label reservation rule.

`RevisionStore` persists pending write intents, lifecycle generations, revisions, issued receive indices and deletion tombstones separately from native stores. `NativeWalletWriter` reconciles pending intents under admission and publishes committed versions; readers subscribe before loading and compare durable versions on resume/open to observe other isolates. Busy, missing stores, repair and process-restart requirements remain typed failures.

`WalletNativeRuntime` installs `NativeWalletWriter` for create/adopt, reveal, sync, delete and repair. Deletion removes the native store and Bitcoin `.parents.sqlite` sidecar, which contains only rebuildable public chain data; the admission database is never unlinked. Background scheduling and notifications remain disabled by the rollout gate.

`WalletSnapshotReader` acquires the same immediate admission for both Bitcoin and Liquid through revision checks and native hydration, releasing it in `finally`. Busy readers return a cached snapshot marked stale or a typed unavailable result instead of waiting behind sync. This barrier protects SDK initialization; it does not claim strictly read-only native opens.

`WalletCatalogPort` reads the existing app Drift catalog through the wallet owner's datasource; it has no native-store access. `LiquidWalletDescriptor` retains the existing confidential descriptor verbatim, including SLIP77 blinding material (no spending keys), solely for native writer/reader use. It is sensitive privacy material: never log it, send it to reporting or export it elsewhere. Its `toString` is explicitly redacted. The contract's conservative key checks do not replace native descriptor parsing. Invalid origins/descriptors become typed failures; legacy datasource programmer errors (for example invalid signer enum decoding) still propagate.

## Foreground Electrum operation

`ElectrumSync.execute(descriptor, discover: false)` opens an existing native store at `nativeWalletStoragePath`. The wallet owner provisions new imports through `NativeWalletWriter.create` before invoking sync. A missing or unreadable store is a failure; it is never deleted or recreated here. The app's existing `SyncWalletUsecase` and `sync: true` repository reads delegate through `ForegroundWalletSync` to this same operation.

Every pass first queries the revealed scripts. At checkpoint height zero or on explicit discovery (`discover: true`), the same pass then full-scans, so payments to unrevealed scripts inside the stop gap are found as well; the pinned bdk_chain full scan counts the stop gap from index 0, which is why it never replaces the revealed-script query. Other passes query revealed scripts only. The batch size remains `(stopGap ~/ 4).clamp(50, 1000)`. The worker opens its own session, applies both updates and persists once with that session's persister before returning success; if either step fails, the pass fails and none of its native result is persisted. The app requests discovery on a pull, on the first automatic Bitcoin pass of the process and then on at most one automatic pass per ten minutes per environment, and from Settings “Scan for missing transactions”. A script beyond both the last revealed index and last-used + stop gap stays unseen until its predecessors are used or revealed. A fresh client is prefilled with wallet transactions/direct anchors and verified parent transactions from the sidecar. The cache is best-effort and self-healing, never authoritative; Electrum still supplies script histories and headers. LWK initializes its bridge in the worker and awaits `sync_` to native completion.

`WalletConnectionPolicy` retains server selection, custom-server isolation and the lifetime of scoped Tor routes. Fallback is limited to connect/ping before native-store opening (opening a BDK persister or LWK wallet can itself write). LWK uses a protocol-only preflight and then its own connection. Its pinned API has no SOCKS support; Liquid keeps the existing direct connection behavior and persists one warning per run when the configured SOCKS route cannot be honored. A later connection failure, load failure or persist failure never causes a second server attempt. LWK status conflicts return `TransactionSyncNeedsRepairFailure`; the app routes explicit repair through `NativeWalletWriter`, preserving issued receive indices and requiring sync before receiving again.

Routine requests for the same key share one future; an explicit discovery queued behind a routine request still runs. `started` and `finished` drive existing foreground indicators. Finished means the attempt ended, including failure; only `Ok<SyncCompletion, ...>` proves persistence. The legacy metadata `syncedAt` behavior remains attempt-based. A separate per-wallet/network SQLite lease serializes native access across isolates: `busy_timeout = 0` and `BEGIN IMMEDIATE`, with asynchronous writer retries for up to one second. Readers attempt admission immediately. The lease is held through actual native completion, never released by a timer; interrupted holders fail closed until process restart. Background rollout remains gated.

## Deferred device timing hook

`SyncCompletion.elapsed` measures the worker's native operation. For comparable foreground wall time, wrap the same call site on the baseline and this branch with the following integration hook (not a unit benchmark):

```dart
Future<int> measureSync(Future<void> Function() synchronize) async {
  final watch = Stopwatch()..start();
  await synchronize();
  return watch.elapsedMilliseconds;
}
// In the existing authenticated integration harness:
// final milliseconds = await measureSync(() => syncWalletUsecase.execute(wallet));
```

Run only after maintainer authorization on a reserved device. Record revision, SDK pin, device/OS, network route, first versus routine versus discovery, cold versus warm sidecar, and elapsed milliseconds. Compare equivalent copies of the same native store on the same chain state and endpoint; do not compare a first scan with a routine sync. Keep wallet identifiers, descriptors, endpoints and transactions out of exported results. Collect multiple runs and report median/range. Real-wallet/device performance measurements are deferred; loopback request-count tests establish cache reuse and parity, not device latency.

## Host-native Liquid smoke test

`native_test/lwk_worker_test.dart` is a separate native integration suite because bull_sdk's Rust shared library is not built by the BDK asset hook used by ordinary Flutter unit tests. Supply the host library built from the pinned SDK (its own locked Cargo build and pinned toolchain), then run on Linux:

```sh
LD_LIBRARY_PATH="$BULL_SDK_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" fvm flutter test packages/transaction_sync/native_test/lwk_worker_test.dart
```

This test has no skip and uses only the published BIP39 vector plus loopback traffic. It verifies real LWK initialization in the worker, fallback before opening, and no retry after opening when a Bitcoin-only fixture rejects Liquid synchronization. It does not establish successful live Liquid synchronization or device lock safety. The compute worker calling BullSdk.init() has not been validated on a phone; that device gate remains open. Normal `make checks` covers `test/`; run this additional suite when changing the native Liquid path.

Sync start, completion, failure and connection fallback are persisted through `bull_logger` on the caller isolate. Completion includes cache state and aggregate counts; no wallet identifiers, descriptors, endpoints, transaction ids or amounts are logged.
