# background_tasks

Headless wallet sync on WorkManager, behind the maintainer gate `backgroundSyncEnabled = false`: nothing is scheduled and the headless entry builds nothing until device validation enables it, on Android and iOS only.

## Runs

`workmanager_runner.dart` receives the task WorkManager resolved, builds only that task (`BackgroundTaskRunner.forTask`), runs it and closes its resources in reverse order, even after a partial startup. Unknown and obsolete tasks are acknowledged without building anything. The published names and ids (`wallets-sync`, `bitcoin-sync`, `liquid-sync`, `swaps-sync`, `logs-prune`) and `lib/core/background_tasks/handler.dart` are fixed.

`RunWalletSyncJobsUsecase` runs the wallets, chain by chain:

1. Admission: the interval is reread (an opt-out from another engine stops the run), revisions are read, one job is claimed.
2. Job: `BackgroundWalletSyncPort` syncs it without an initial scan, while the lease is renewed. An admitted native operation is always awaited, even past the budget.
3. Settlement: the queue completes the claim, then `PaymentAnnouncementPort.record` stores what the committed sync saw; its failure never fails the sync.

After the chain, `deliverPending` shows the announcements. A refused permission is final; any other failure asks WorkManager for a retry. Bitcoin admissions use at most half the budget.

## Queue

`SqliteWalletSyncJobQueueRepository` keeps scheduling state only: hashed wallet identities, stamps, attempts, backoff and leases. Lease tokens keep a stale run from completing a job another run took over; they never own or release the native writer lock. Every operation returns a `Result` that tells a lost claim from a storage failure. The queue is created by a single `CREATE` with `user_version` 1 through `openForeground`; `openExisting` never creates or migrates it.

## Phase A

`background_tasks` still depends on `notifications`: `NotificationsPaymentAnnouncement` implements the announcement port here, and `WalletTransactionSyncBackgroundTask`, `SqliteWalletSyncJobQueue` and the `BackgroundWalletSync` alias remain for `lib/features/wallet`. Phase B moves that composition and the announcement to the wallet feature, opens the queue with `openExisting` in the background and creates it in the foreground.
