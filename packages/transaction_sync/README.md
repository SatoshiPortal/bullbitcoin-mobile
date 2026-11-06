# transaction_sync

The native wallet writer contracts and foreground Electrum sync operation. The application depends on this package; this package never imports `bb_mobile`. Flutter is required by bull_sdk and isolate execution; no SDK handles cross the public API.

`WalletKey` is the wallet id plus a primitives network. Engine, endpoint and tuning changes do not change identity. `nativeWalletStoragePath` preserves the legacy UTF-16 hex id and exact BDK suffix/LWK root; it performs no IO. Readers and writers will adopt this function at their respective cutovers. Callers pass `getApplicationDocumentsDirectory().path` verbatim. Bitcoin regtest requires a distinct id ending in `:regtest`; the full id is hex-encoded, so it cannot reuse the historical testnet origin path. Regtest provisioning accepts only bip84 native witness descriptors on both receive and change branches. Signet and Liquid regtest remain typed unsupported at native admission; Liquid support awaits lwk-dart #96 in the pinned SDK.

`WalletConnectionPolicy` owns connection selection through its app implementation. Its callback runs within the existing Electrum policy's scoped Tor route. Only the caller knows whether mutation has started; `mayRetry` must refuse fallback after that point. Exhausted fallback returns the caller's last typed failure; failures before any callback result map to `TransactionSyncConnectionFailure`. Connection values must not escape the callback's lifetime. The labels owner retains the existing system-label reservation rule.

Revision readers and Liquid read admission are interfaces only. D will implement pending intent reconciliation, generations, tombstones and publication. Subscribe before loading, and compare durable versions on resume/open. A Liquid read lease lasts through hydration and is released in `finally`; BDK readers do not acquire that barrier. Writer outcomes carry the committed version; busy, missing stores, repair and process-restart requirements are explicit failures.

No coordinator, lock, revision store, background job, notification system or reader cutover is included here. Background tasks remain disabled. Create, reveal, delete and repair stay on the legacy routes until lane D. In particular, D must remove the `.parents.sqlite` sidecar when deleting its native store; A does not change deletion. A leftover sidecar holds only rebuildable public chain data and never determines wallet state.

`WalletCatalogPort` reads the existing app Drift catalog through the wallet owner's datasource; it has no native-store access. `LiquidWalletDescriptor` retains the existing confidential descriptor verbatim, including SLIP77 blinding material (no spending keys), solely for native writer/reader use. It is sensitive privacy material: never log it, send it to reporting or export it elsewhere. Its `toString` is explicitly redacted. The contract's conservative key checks do not replace native descriptor parsing. Invalid origins/descriptors become typed failures; legacy datasource programmer errors (for example invalid signer enum decoding) still propagate.

## Foreground Electrum operation

`ElectrumSync.execute(descriptor, discover: false)` opens an existing native store at `nativeWalletStoragePath`. The wallet owner provisions new imports through its existing legacy route before invoking sync. A missing or unreadable store is a failure; it is never deleted or recreated here. The app's existing `SyncWalletUsecase` and `sync: true` repository reads delegate through `ForegroundWalletSync` to this same operation.

BDK full-scans at checkpoint height zero or on explicit discovery; routine foreground refreshes and background sync query revealed scripts. The batch size remains `(stopGap ~/ 4).clamp(50, 1000)`. The worker opens its own session, applies the update and persists with that session's persister before returning success. A fresh client is prefilled with wallet transactions/direct anchors and verified parent transactions from the sidecar. The cache is best-effort and self-healing, never authoritative; Electrum still supplies script histories and headers. LWK initializes its bridge in the worker and awaits `sync_` to native completion.

Background runs request `revealedScripts` (`discover: false`, `allowInitialScan: false`, `reason=background`) to cover every address this device has revealed. The pinned bdk-dart `757d4e8` uses bdk_chain 0.23.3, whose discovery scan counts the stop gap from index 0 without the last-revealed bound and can miss a payment beyond last-used + stop gap (for example, revealed index 30 with stop gap 20). Until the binding pins bdk_chain ≥ 0.23.4 ([upstream fix #2222](https://github.com/bitcoindevkit/bdk/pull/2222)), explicit discovery remains on Settings “Scan for missing transactions”, for addresses this device never revealed; it is not a substitute for revealed-script coverage.

`WalletConnectionPolicy` retains server selection, custom-server isolation and the lifetime of scoped Tor routes. Fallback is limited to connect/ping before native-store opening (opening a BDK persister or LWK wallet can itself write). LWK uses a protocol-only preflight and then its own connection. Its pinned API has no SOCKS support; Liquid keeps the existing direct connection behavior and persists one warning per run when the configured SOCKS route cannot be honored. A later connection failure, load failure or persist failure never causes a second server attempt. LWK status conflicts return `TransactionSyncNeedsRepairFailure`; the temporary app bridge maps this to the existing startup conflict failure until the writer repair cutover.

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

This test has no skip and uses only the published BIP39 vector plus loopback traffic. It verifies real LWK initialization in the worker, fallback before opening, and no retry after opening when a Bitcoin-only fixture rejects Liquid synchronization. It does not establish successful live Liquid synchronization or device lock safety. The compute worker calling BullSdk.init() has not been validated on a phone; that device gate remains open. Normal `make checks` covers `test/`; run this additional suite when changing the native Liquid path.

Sync start, completion, failure and connection fallback are persisted through `bull_logger` on the caller isolate. Completion includes cache state and aggregate counts; no wallet identifiers, descriptors, endpoints, transaction ids or amounts are logged.

## Bitcoin regtest host test

The explicit native suite exercises offline writer creation, bcrt1 receive, Nigiri faucet funding, writer-owned discovery, native reader hydration, an explicit-fee signed broadcast, sync/history, fresh-reader reopening and headless sync. It uses the published BIP39 test vector and disposable native stores. Start a disposable Nigiri service separately; the test never starts or reconfigures it. From this package directory:

```sh
fvm flutter test --no-pub native_test/native_regtest_nigiri_test.dart
```

The defaults are the local development Electrum port 50000 and faucet port 3000. Override with `--dart-define=NIGIRI_ELECTRUM=...` and `--dart-define=NIGIRI_FAUCET=...`. Ordinary unit checks do not require this service. This native test does not validate app navigation, wallet import or mobile lifecycle behavior.

`read.dart` also publishes `validateAddress(address, network)` for payment consumers. It validates against captured concrete network context, rejects Liquid regtest and signet, and limits regtest destinations to the distinct bcrt1 witness encoding. Bitcoin testnet Base58 remains accepted; address bytes cannot distinguish its provenance from regtest. This is destination authorization, not URI parsing or an Electrum genesis check.
