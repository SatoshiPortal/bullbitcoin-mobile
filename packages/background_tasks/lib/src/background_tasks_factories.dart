import 'package:primitives/primitives.dart';

import 'data/sqlite_wallet_sync_job_queue_repository.dart';
import 'domain/background_tasks_failure.dart';
import 'domain/repositories/wallet_sync_job_queue_repository.dart';

/// Opens the wallet sync queue at [path], creating it on first use. Only the
/// foreground calls it; [WalletSyncJobQueueRepository.close] releases it.
Result<WalletSyncJobQueueRepository, BackgroundTasksFailure>
openForegroundWalletSyncJobQueue(String path) =>
    SqliteWalletSyncJobQueueRepository.openForeground(path);

/// Opens a queue the foreground created, never creating nor migrating it:
/// a missing, older or newer queue is refused.
Result<WalletSyncJobQueueRepository, BackgroundTasksFailure>
openExistingWalletSyncJobQueue(String path) =>
    SqliteWalletSyncJobQueueRepository.openExisting(path);
