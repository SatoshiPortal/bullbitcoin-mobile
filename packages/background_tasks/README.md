# background_tasks

This Flutter-headless package orchestrates scheduled wallet synchronization, notification reconciliation, log pruning, and compatibility handling for persisted swap tasks. WorkManager is confined to `BackgroundTaskWorkmanagerAdapter`; application code uses the testable runner and typed callbacks.

The shell must provide a top-level `@pragma('vm:entry-point')` callback dispatcher and a top-level bootstrap that constructs fresh dependencies in the WorkManager isolate. The package does not share mutable state between isolates. Native WorkManager setup remains in the shell.

The bootstrap must initialize `NotificationsFacade` before building the runner. A shell can keep its own top-level dispatcher while delegating execution to the package:

```dart
@pragma('vm:entry-point')
void callbackDispatcher() => runWorkmanagerTaskDispatcher(() async {
  final notifications = await buildNotificationsFacadeAndInitialize();
  final walletTask = buildWalletTask(notifications);
  return BackgroundTaskRunner.compatibility(
    logger: buildBackgroundLogger(),
    bitcoinSync: () => walletTask.execute(chain: 'bitcoin'),
    liquidSync: () => walletTask.execute(chain: 'liquid'),
    pruneLogs: pruneLogs,
    onFinished: () async {
      await walletSyncFacade.dispose();
      metadataStore.close();
      notificationOutbox.dispose();
      await driftDatabase.close();
    },
  );
 });
 ```

The `onFinished` hook is called after log flushing, including when a task fails. The shell must use it to close every isolate-owned resource: the wallet sync facade, SQLite sync metadata store, durable sync queue, notification outbox, and Drift database. Keep these resources local to the bootstrap and do not share them with another isolate.

The shell supplies each `WalletTransactionSyncBackgroundJob` with a `WalletNetworkKey` and a synchronization callback. The key selects the chain and derives notification topic/event identifiers; the callback remains free to construct the effective source registration with the endpoint selected by the shell. Incoming notifications are reconciled from the complete current transaction collection, filtered to `incoming` transactions whose `selfTransfer` is not `true`. One notification per transaction is acceptable in this first tranche. Topic and event identifiers are versioned SHA-256 values; raw wallet IDs and transaction IDs are not logged or persisted by this package. Titles and bodies are supplied by the shell, and destination is `walletHome`.

Wallet selection is persisted by `SqliteWalletSyncJobQueue`. Each invocation atomically reconciles the current wallet set, claims at most `maxJobsPerRun` jobs, and executes the claimed callbacks through a FIFO worker pool bounded by `maxConcurrentJobs`. Both defaults are 2. Never-synchronized wallets are selected first in stable insertion order; after every current wallet has succeeded once, the least recently successful wallets rotate first. Five wallets therefore rotate in batches of 2, 2, and 1 before the oldest successful wallet is selected again. Transient failures use persisted bounded exponential backoff, permanent failures remain disabled until the job's source revision changes, and expiring leases allow a later WorkManager process to recover interrupted work. An active lease is renewed while its callback runs and all completion writes are conditional on the lease token.

The queue database stores only SHA-256 job identities, normalized chain/network categories, source revision, scheduling timestamps, counters, and lease state; it never stores raw wallet IDs. Persisted CONFIG/FINE/WARNING diagnostics contain only validated chain names, aggregate counts, limits, and fixed failure categories. They never contain wallet identities or hashes, lease tokens, source configuration, transaction data, endpoints, or raw exceptions. The Bitcoin and Liquid WorkManager tasks remain distinct invocations, while `DurableWalletSourceOperationCoordinator` provides the separate global network-synchronization limit across chains and isolates.

Android and iOS require the shell's existing WorkManager/native registration. Desktop can use the runner directly, but has no native WorkManager scheduling adapter. The shell remains responsible for dependency composition, native configuration, and registration policy.

Official sources (accessed 2026-09-02): [Workmanager package](https://pub.dev/packages/workmanager), [Workmanager changelog](https://pub.dev/packages/workmanager/changelog). Version `0.10.9` is used; it requires Flutter 3.38+, and the repository pins Flutter 3.44.9. Version 0.10.9 includes the Android 16 RUNNING-task fix.
