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

The `onFinished` hook is called after log flushing, including when a task fails. The shell must use it to close every isolate-owned resource: the wallet sync facade, SQLite sync metadata store, notification outbox, and Drift database. Keep these resources local to the bootstrap and do not share them with another isolate.

The shell supplies each `WalletTransactionSyncBackgroundJob` with a `WalletNetworkKey` and a synchronization callback. The key selects the chain and derives notification topic/event identifiers; the callback remains free to construct the effective source registration with the endpoint selected by the shell. Incoming notifications are reconciled from the complete current transaction collection, filtered to `incoming` transactions whose `selfTransfer` is not `true`. One notification per transaction is acceptable in this first tranche. Topic and event identifiers are versioned SHA-256 values; raw wallet IDs and transaction IDs are not logged or persisted by this package. Titles and bodies are supplied by the shell, and destination is `walletHome`.

Android and iOS require the shell's existing WorkManager/native registration. Desktop can use the runner directly, but has no native WorkManager scheduling adapter. The shell remains responsible for dependency composition, native configuration, and registration policy.

Official sources (accessed 2026-09-02): [Workmanager package](https://pub.dev/packages/workmanager), [Workmanager changelog](https://pub.dev/packages/workmanager/changelog). Version `0.10.9` is used; it requires Flutter 3.38+, and the repository pins Flutter 3.44.9. Version 0.10.9 includes the Android 16 RUNNING-task fix.
