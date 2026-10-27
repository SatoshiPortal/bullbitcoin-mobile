import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

import 'background_task_execution_result.dart';
import 'sqlite_wallet_sync_job_queue.dart';
import 'wallet_payment_notification_identity.dart';

typedef SyncJobOperation =
    Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
    Function();
typedef NotificationCopy = ({String title, String body});
typedef NotificationCopyBuilder =
    NotificationCopy Function(int count, String chain);

final class WalletTransactionSyncBackgroundJob {
  final WalletNetworkKey key;
  final SyncJobOperation synchronize;
  final String queueRevision;

  const WalletTransactionSyncBackgroundJob({
    required this.key,
    required this.synchronize,
    this.queueRevision = 'legacy-electrum-v1',
  });
}

final class WalletTransactionSyncBackgroundTask {
  final NotificationsFacade notifications;
  final List<WalletTransactionSyncBackgroundJob> jobs;
  final NotificationCopyBuilder copy;
  final int maxConcurrentJobs;
  final WalletSyncJobQueue queue;
  final int maxJobsPerRun;
  final Duration renewalInterval;

  WalletTransactionSyncBackgroundTask({
    required this.notifications,
    required this.jobs,
    required this.copy,
    this.maxConcurrentJobs = 2,
    required this.queue,
    this.maxJobsPerRun = 2,
    this.renewalInterval = const Duration(minutes: 5),
    WalletSyncLogSink? logSink,
  }) : _sink = logSink ?? const BullLoggerWalletSyncLogSink() {
    if (maxConcurrentJobs <= 0) {
      throw ArgumentError.value(
        maxConcurrentJobs,
        'maxConcurrentJobs',
        'must be greater than zero',
      );
    }
    if (maxJobsPerRun <= 0) {
      throw ArgumentError.value(
        maxJobsPerRun,
        'maxJobsPerRun',
        'must be greater than zero',
      );
    }
    if (renewalInterval <= Duration.zero ||
        renewalInterval >= queue.leaseDuration) {
      throw ArgumentError.value(
        renewalInterval,
        'renewalInterval',
        'must be shorter than the queue lease',
      );
    }
  }

  final WalletSyncLogSink _sink;

  Future<BackgroundTaskExecutionResult> execute({required String chain}) async {
    if (chain != 'bitcoin' && chain != 'liquid') {
      return const BackgroundTaskExecutionResult.permanentFailure();
    }
    final stopwatch = Stopwatch()..start();
    var retry = false;
    var permanent = false;
    var newIncoming = 0;
    var succeeded = 0;
    var retried = 0;
    var permanentlyFailed = 0;
    final eligibleJobs = jobs.where((job) => job.key.chain == chain).toList();
    final claims = await queue.reconcileAndClaim(
      eligibleJobs.map((job) => (key: job.key, revision: job.queueRevision)),
      chain: chain,
      maxJobs: maxJobsPerRun,
    );
    final jobsByKey = {for (final job in eligibleJobs) job.key: job};
    final observations = List<NotificationTopicObservation?>.filled(
      claims.length,
      null,
    );
    var nextJob = 0;

    Future<void> runWorker() async {
      while (nextJob < claims.length) {
        final index = nextJob++;
        final claim = claims[index];
        final job = jobsByKey[claim.key];
        if (job == null) {
          retry = true;
          try {
            await queue.completeFailure(claim, permanent: false);
          } catch (_) {
            _safeLog(
              WalletSyncLogLevel.warning,
              'Wallet sync queue failure category=missing_job_cleanup',
            );
          }
          continue;
        }
        Timer? renewal;
        Future<void>? activeRenewal;
        var renewalFailed = false;

        Future<void> renewLease() async {
          try {
            if (!await queue.renew(claim)) renewalFailed = true;
          } catch (_) {
            renewalFailed = true;
          } finally {
            activeRenewal = null;
          }
        }

        Future<void> stopRenewal() async {
          renewal?.cancel();
          renewal = null;
          await activeRenewal;
        }

        try {
          renewal = Timer.periodic(renewalInterval, (_) {
            activeRenewal ??= renewLease();
          });
          final sync = await job.synchronize();
          await stopRenewal();
          switch (sync) {
            case Err(:final failure):
              _classifySync(
                failure,
                onRetry: () => retry = true,
                onPermanent: () => permanent = true,
              );
              if (_isPermanent(failure)) {
                permanentlyFailed++;
              } else {
                retried++;
              }
              final completed = await queue.completeFailure(
                claim,
                permanent: _isPermanent(failure),
              );
              if (renewalFailed || !completed) {
                retry = true;
              }
              _safeLog(
                WalletSyncLogLevel.warning,
                'Wallet sync ${_isPermanent(failure) ? 'permanent' : 'retryable'} '
                'failure chain=$chain category=${_category(failure)}',
              );
            case Ok(:final value):
              final completed = await queue.completeSuccess(claim);
              if (completed) {
                succeeded++;
                newIncoming += value.newIncomingTransactions.length;
                observations[index] = _observationFor(job, value);
              }
              if (renewalFailed || !completed) {
                retry = true;
              }
          }
        } catch (_) {
          await stopRenewal();
          retry = true;
          _safeLog(
            WalletSyncLogLevel.warning,
            'Wallet sync queue failure category=operation_exception',
          );
          try {
            if (!await queue.completeFailure(claim, permanent: false)) {
              retry = true;
            }
          } catch (_) {
            _safeLog(
              WalletSyncLogLevel.warning,
              'Wallet sync queue failure category=completion_exception',
            );
          }
        } finally {
          await stopRenewal();
        }
      }
    }

    final workerCount = maxConcurrentJobs < claims.length
        ? maxConcurrentJobs
        : claims.length;
    await Future.wait(List.generate(workerCount, (_) => runWorker()));
    _safeLog(
      WalletSyncLogLevel.fine,
      'Wallet sync queue completion: chain=$chain claimed=${claims.length} '
      'succeeded=$succeeded retried=$retried permanent=$permanentlyFailed '
      'new_incoming=$newIncoming elapsed_ms=${stopwatch.elapsedMilliseconds}',
    );

    final completedObservations = observations
        .whereType<NotificationTopicObservation>()
        .toList();
    if (completedObservations.isNotEmpty) {
      final reconciled = await notifications.reconcileTopicsAndEnqueue(
        completedObservations,
        (newEvents) {
          final eventIds = newEvents.map((event) => event.eventId).toList()
            ..sort();
          final text = copy(newEvents.length, chain);
          return LocalNotification(
            eventId: sha256
                .convert(
                  utf8.encode(
                    'background-notifications-v2|$chain|${eventIds.join('|')}',
                  ),
                )
                .toString(),
            title: text.title,
            body: text.body,
            destination: NotificationDestination.walletHome,
            createdAt: newEvents
                .map((event) => event.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b),
          );
        },
      );
      switch (reconciled) {
        case Err(:final failure):
          _safeLog(
            WalletSyncLogLevel.warning,
            'Wallet sync notification failure stage=reconcile '
            'category=${failure.runtimeType}',
          );
          _classifyNotification(
            failure,
            onRetry: () => retry = true,
            onPermanent: () => permanent = true,
          );
        case Ok(:final value) when value.skippedTopicCount > 0:
          // Announced only once the foreground has recorded what the user
          // sees; until then a wallet's history would read as new payments.
          _safeLog(
            WalletSyncLogLevel.fine,
            'Wallet sync notifications skipped: chain=$chain '
            'wallets_without_baseline=${value.skippedTopicCount}',
          );
        case Ok():
          break;
      }
    }
    try {
      final delivered = await notifications.deliverPending();
      if (delivered case Err(:final failure)) {
        _safeLog(
          WalletSyncLogLevel.warning,
          'Wallet sync notification failure stage=deliver '
          'category=${failure.runtimeType}',
        );
        _classifyNotification(
          failure,
          onRetry: () => retry = true,
          onPermanent: () => permanent = true,
        );
      }
    } catch (_) {
      _safeLog(
        WalletSyncLogLevel.warning,
        'Wallet sync notification failure stage=deliver category=exception',
      );
      retry = true;
    }
    if (retry) return const BackgroundTaskExecutionResult.retry();
    if (permanent) {
      return const BackgroundTaskExecutionResult.permanentFailure();
    }
    return const BackgroundTaskExecutionResult.success();
  }

  void _safeLog(WalletSyncLogLevel level, String message) {
    try {
      _sink.write(level, message);
    } catch (_) {}
  }

  /// A fixed label: the failure type, plus the reason of a source failure.
  static String _category(WalletTransactionSyncFailure failure) =>
      switch (failure) {
        SourceFailure(:final reason) => 'SourceFailure.${reason.name}',
        _ => failure.runtimeType.toString(),
      };

  static bool _isPermanent(WalletTransactionSyncFailure failure) {
    var permanent = false;
    _classifySync(failure, onRetry: () {}, onPermanent: () => permanent = true);
    return permanent;
  }

  static NotificationTopicObservation _observationFor(
    WalletTransactionSyncBackgroundJob job,
    WalletTransactionSyncOutcome outcome,
  ) {
    final events = outcome.snapshot.transactions
        .where(
          (transaction) =>
              transaction.direction == TransactionDirection.incoming &&
              transaction.selfTransfer != true,
        )
        .map(
          (transaction) => WalletPaymentNotificationIdentity.event(
            job.key,
            transaction.txid,
            observedAt: outcome.snapshot.observedAt,
          ),
        )
        .toList();
    return NotificationTopicObservation(
      WalletPaymentNotificationIdentity.topicId(job.key),
      events,
    );
  }

  static void _classifySync(
    WalletTransactionSyncFailure failure, {
    required void Function() onRetry,
    required void Function() onPermanent,
  }) => switch (failure) {
    SourceFailure(reason: SourceFailureReason.unavailable) ||
    SourceFailure(reason: SourceFailureReason.unknown) ||
    SourceStorageFailure() ||
    CoordinationTimeoutFailure() ||
    SnapshotExpiredFailure() => onRetry(),
    SnapshotNotInitializedFailure() ||
    WalletRegistrationMismatchFailure() ||
    WalletSourceStateMissingFailure() ||
    WalletSourceStateIncompatibleFailure() ||
    DeletedWalletFailure() ||
    SourceFailure(reason: SourceFailureReason.rejected) ||
    SourceObservationMismatchFailure() ||
    ExtractionFailure() ||
    DeletionFailure() ||
    InvalidPaginationFailure() => onPermanent(),
  };

  static void _classifyNotification(
    NotificationsFailure failure, {
    required void Function() onRetry,
    required void Function() onPermanent,
  }) => switch (failure) {
    UnknownNotificationDestinationFailure() ||
    InvalidNotificationPayloadFailure() => onPermanent(),
    NotificationsStorageFailure() ||
    NotificationsGatewayFailure() ||
    NotificationsClaimLostFailure() => onRetry(),
    // Nothing to retry: the pending notifications wait for a later run, once
    // the user has granted the permission.
    NotificationsPermissionDeniedFailure() => null,
  };
}
