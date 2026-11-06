# transaction_sync

Pure-Dart contracts for the native wallet writer. The application depends on this package; this package never imports `bb_mobile`. This scaffold does not open native stores or change application behavior.

`WalletKey` is the wallet id plus a primitives network. Engine, endpoint and tuning changes do not change identity. `nativeWalletStoragePath` preserves the legacy UTF-16 hex id and exact BDK suffix/LWK root; it performs no IO. Readers and writers will adopt this function at their respective cutovers. Callers pass `getApplicationDocumentsDirectory().path` verbatim. Signet/regtest throw `ArgumentError`: their legacy origins share testnet coin type 1, so enabling them requires catalog uniqueness and a storage migration first.

`WalletConnectionPolicy` owns connection selection through its app implementation. Its callback runs within the existing Electrum policy's scoped Tor route. Only the caller knows whether mutation has started; `mayRetry` must refuse fallback after that point. Exhausted fallback returns the caller's last typed failure; failures before any callback result map to `TransactionSyncConnectionFailure`. Connection values must not escape the callback's lifetime. The labels owner retains the existing system-label reservation rule.

Revision readers and Liquid read admission are interfaces only. D will implement pending intent reconciliation, generations, tombstones and publication. Subscribe before loading, and compare durable versions on resume/open. A Liquid read lease lasts through hydration and is released in `finally`; BDK readers do not acquire that barrier. Writer outcomes carry the committed version; busy, missing stores, repair and process-restart requirements are explicit failures.

No engine, coordinator, lock, revision store, background job, notification system or reader cutover is included here.

`WalletCatalogPort` reads the existing app Drift catalog through the wallet owner's datasource; it has no native-store access. `LiquidWalletDescriptor` retains the existing confidential descriptor verbatim, including SLIP77 blinding material (no spending keys), solely for native writer/reader use. It is sensitive privacy material: never log it, send it to reporting or export it elsewhere. Its `toString` is explicitly redacted. The contract's conservative key checks do not replace native descriptor parsing. Invalid origins/descriptors become typed failures; legacy datasource programmer errors (for example invalid signer enum decoding) still propagate.
