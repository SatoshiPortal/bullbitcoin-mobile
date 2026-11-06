# transaction_sync

The native wallet writer contracts and foreground Electrum sync operation. The application depends on this package; this package never imports `bb_mobile`. Flutter is required by bull_sdk and isolate execution; no SDK handles cross the public API.

`WalletKey` is the wallet id plus a primitives network. Engine, endpoint and tuning changes do not change identity. `nativeWalletStoragePath` preserves the legacy UTF-16 hex id and exact BDK suffix/LWK root; it performs no IO. Readers and writers will adopt this function at their respective cutovers. Callers pass `getApplicationDocumentsDirectory().path` verbatim. Signet/regtest throw `ArgumentError`: their legacy origins share testnet coin type 1, so enabling them requires catalog uniqueness and a storage migration first.

`WalletConnectionPolicy` owns connection selection through its app implementation. Its callback runs within the existing Electrum policy's scoped Tor route. Only the caller knows whether mutation has started; `mayRetry` must refuse fallback after that point. Exhausted fallback returns the caller's last typed failure; failures before any callback result map to `TransactionSyncConnectionFailure`. Connection values must not escape the callback's lifetime. The labels owner retains the existing system-label reservation rule.

Revision readers and Liquid read admission are interfaces only. D will implement pending intent reconciliation, generations, tombstones and publication. Subscribe before loading, and compare durable versions on resume/open. A Liquid read lease lasts through hydration and is released in `finally`; BDK readers do not acquire that barrier. Writer outcomes carry the committed version; busy, missing stores, repair and process-restart requirements are explicit failures.

No coordinator, lock, revision store, background job, notification system or reader cutover is included here. Background tasks remain disabled. Create, reveal, delete and repair stay on the legacy routes until lane D. In particular, D must remove the `.parents.sqlite` sidecar when deleting its native store; A does not change deletion. A leftover sidecar holds only rebuildable public chain data and never determines wallet state.

`WalletCatalogPort` reads the existing app Drift catalog through the wallet owner's datasource; it has no native-store access. `LiquidWalletDescriptor` retains the existing confidential descriptor verbatim, including SLIP77 blinding material (no spending keys), solely for native writer/reader use. It is sensitive privacy material: never log it, send it to reporting or export it elsewhere. Its `toString` is explicitly redacted. The contract's conservative key checks do not replace native descriptor parsing. Invalid origins/descriptors become typed failures; legacy datasource programmer errors (for example invalid signer enum decoding) still propagate.

## Foreground Electrum operation

`ElectrumSync.execute(descriptor, discover: false)` opens an existing native store at `nativeWalletStoragePath`. The wallet owner provisions new imports through its existing legacy route before invoking sync. A missing or unreadable store is a failure; it is never deleted or recreated here. The app's existing `SyncWalletUsecase` and `sync: true` repository reads delegate through `ForegroundWalletSync` to this same operation.

BDK full-scans at checkpoint height zero or on explicit discovery; routine sync queries revealed scripts. The batch size remains `(stopGap ~/ 4).clamp(50, 1000)`. The worker opens its own session, applies the update and persists with that session's persister before returning success. A fresh client is prefilled with wallet transactions/direct anchors and verified parent transactions from the sidecar. The cache is best-effort and self-healing, never authoritative; Electrum still supplies script histories and headers. LWK initializes its bridge in the worker and awaits `sync_` to native completion.

`WalletConnectionPolicy` retains server selection, custom-server isolation and the lifetime of scoped Tor routes. Fallback is limited to connect/ping before native-store opening (opening a BDK persister or LWK wallet can itself write). LWK uses a protocol-only preflight and then its own connection. Its pinned API has no SOCKS support, so a policy-supplied SOCKS route is rejected before connecting rather than silently bypassed. A later connection failure, load failure or persist failure never causes a second server attempt. LWK status conflicts return `TransactionSyncNeedsRepairFailure`; no repair is attempted.

Routine requests for the same key share one future; an explicit discovery queued behind a routine request still runs. `started` and `finished` drive existing foreground indicators. Finished means the attempt ended, including failure; only `Ok<SyncCompletion, ...>` proves persistence. The legacy metadata `syncedAt` behavior remains attempt-based. This in-process serialization is not a cross-isolate lock and does not authorize background writes.

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

This test has no skip and uses only the published BIP39 vector plus loopback traffic. It verifies real LWK initialization in the worker, fallback before opening, and no retry after opening when a Bitcoin-only fixture rejects Liquid synchronization. It does not establish successful live Liquid synchronization or device lock safety. Normal `make checks` covers `test/`; run this additional suite when changing the native Liquid path.

Sync start, completion, failure and connection fallback are persisted through `bull_logger` on the caller isolate. Completion includes cache state and aggregate counts; no wallet identifiers, descriptors, endpoints, transaction ids or amounts are logged.
