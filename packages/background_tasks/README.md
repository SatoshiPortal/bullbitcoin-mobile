# background_tasks

This Flutter-headless package orchestrates scheduled wallet synchronization, notification reconciliation, log pruning, and compatibility handling for persisted swap tasks. WorkManager is confined to `BackgroundTaskWorkmanagerAdapter`; application code uses the testable runner and typed callbacks.

The shell must provide a top-level `@pragma('vm:entry-point')` callback dispatcher and a top-level bootstrap that constructs fresh dependencies in the WorkManager isolate. The package does not share mutable state between isolates. Native WorkManager setup remains in the shell.

The bootstrap must initialize `NotificationsFacade` before building the runner. A shell can keep its own top-level dispatcher while delegating execution to the package:

```dart
@pragma('vm:entry-point')
void callbackDispatcher() => runWorkmanagerTaskDispatcher(() async {
  final launch = Stopwatch()..start();
  final notifications = await buildNotificationsFacadeAndInitialize();
  final walletTask = buildWalletTask(notifications);
  return BackgroundTaskRunner.compatibility(
    logger: buildBackgroundLogger(),
    walletsSync: () => walletTask.executeAll(clock: launch),
    // Kept for schedules registered by older releases.
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

Wallet selection is persisted by `SqliteWalletSyncJobQueue`. Each worker of a pool bounded by `maxConcurrentJobs` claims one wallet when it is about to start it, after reconciling the current wallet set, up to `maxJobsPerRun` wallets per invocation; a claim counts as an attempt, so no wallet is claimed that the run might not start. Both defaults are 2. Wallets with the fewest consecutive attempts are selected first, so one whose runs keep failing or being stopped cannot starve the others; among them, never-synchronized wallets come first in stable insertion order, then the least recently successful ones. Five wallets therefore rotate in batches of 2, 2, and 1 before the oldest successful wallet is selected again. Transient failures use persisted bounded exponential backoff, permanent failures remain disabled until the job's source revision changes, and expiring leases allow a later WorkManager process to recover interrupted work. An active lease is renewed while its callback runs and all completion writes are conditional on the lease token.

The queue database stores only SHA-256 job identities, normalized chain/network categories, source revision, scheduling timestamps, counters, and lease state; it never stores raw wallet IDs. Persisted CONFIG/FINE/WARNING diagnostics contain only validated chain names, aggregate counts, limits, and fixed failure categories. They never contain wallet identities or hashes, lease tokens, source configuration, transaction data, endpoints, or raw exceptions. One WorkManager task, `walletsSync`, runs Bitcoin then Liquid under one budget counted from the task's launch, while `DurableWalletSourceOperationCoordinator` provides the separate global network-synchronization limit across chains and isolates.

Android and iOS require the shell's existing WorkManager/native registration. Desktop can use the runner directly, but has no native WorkManager scheduling adapter. The shell remains responsible for dependency composition, native configuration, and registration policy.

Official sources (accessed 2026-09-02): [Workmanager package](https://pub.dev/packages/workmanager), [Workmanager changelog](https://pub.dev/packages/workmanager/changelog). The version is the one resolved in the root `pubspec.lock` (0.10.10 as of 2026-10-28); it requires Flutter 3.38+, and the repository pins Flutter 3.44.9. It includes the Android 16 RUNNING-task fix shipped in 0.10.9.
