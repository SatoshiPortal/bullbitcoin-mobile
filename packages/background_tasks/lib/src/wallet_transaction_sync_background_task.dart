import 'package:bull_logger/bull_logger.dart' show log;
import 'package:notifications/notifications.dart';
import 'package:transaction_sync/transaction_sync.dart';

import 'background_task_logger.dart';
import 'data/notifications_payment_announcement.dart';
import 'data/shared_preferences_background_sync_interval_repository.dart';
import 'domain/background_task_execution_result.dart';
import 'domain/ports/background_wallet_sync_port.dart';
import 'domain/repositories/wallet_sync_job_queue_repository.dart';
import 'domain/run_wallet_sync_jobs_usecase.dart';

/// Phase A: the name lib/features/wallet still implements.
typedef BackgroundWalletSync = BackgroundWalletSyncPort;

/// Phase A: the composition lib/features/wallet still calls by this name.
/// Phase B builds [RunWalletSyncJobsUsecase] there and deletes this file.
final class WalletTransactionSyncBackgroundTask {
  final RunWalletSyncJobsUsecase _usecase;

  WalletTransactionSyncBackgroundTask({
    required BackgroundWalletSyncPort writer,
    required WalletRevisionReaderPort revisions,
    required Iterable<WalletKey> keys,
    required WalletSyncJobQueueRepository queue,
    required NotificationsFacade? notifications,
    required NotificationCopyBuilder copy,
    BackgroundTaskLogger? logSink,
    Duration? runBudget,
  }) : _usecase = RunWalletSyncJobsUsecase(
         wallets: writer,
         revisions: revisions,
         keys: keys,
         queue: queue,
         intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
         announcements: notifications == null
             ? null
             : NotificationsPaymentAnnouncement(notifications, copy),
         logger: logSink ?? LoggerBackgroundTaskLogger(log),
         runBudget: runBudget,
       );

  Future<BackgroundTaskExecutionResult> executeAll({Stopwatch? clock}) =>
      _usecase.execute(clock: clock);
}
