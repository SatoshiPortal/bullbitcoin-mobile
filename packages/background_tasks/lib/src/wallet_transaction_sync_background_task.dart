import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
    this.runBudget,
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

  /// Once spent, no further wallet is started: the platform stops a run that
  /// overstays (about 30 s on iOS) and its unfinished work would be lost.
  final Duration? runBudget;

  /// Bitcoin then Liquid in one run, under one budget: a single platform job
  /// keeps the network for both, where two jobs in one process lost it as
  /// soon as the first one finished. [clock], started when the platform
  /// launched the run, makes the budget include startup.
  Future<BackgroundTaskExecutionResult> executeAll({Stopwatch? clock}) async {
    clock ??= Stopwatch()..start();
    var retry = false;
    var permanent = false;
    final budget = runBudget;
    for (final chain in const ['bitcoin', 'liquid']) {
      // Bitcoin stops starting wallets at half the budget so Liquid always
      // gets its turn; Liquid may use whatever is left.
      final result = await execute(
        chain: chain,
        clock: clock,
        admissionLimit: chain == 'bitcoin' && budget != null
            ? budget ~/ 2
            : null,
      );
      switch (result.status) {
        case BackgroundTaskExecutionStatus.retry:
          retry = true;
        case BackgroundTaskExecutionStatus.permanentFailure:
          permanent = true;
        case BackgroundTaskExecutionStatus.success:
          break;
      }
    }
    if (retry) return const BackgroundTaskExecutionResult.retry();
    if (permanent) {
      return const BackgroundTaskExecutionResult.permanentFailure();
    }
    return const BackgroundTaskExecutionResult.success();
  }

  /// [clock] carries the elapsed budget across chains of one run;
  /// [admissionLimit] stops starting wallets earlier than [runBudget].
  Future<BackgroundTaskExecutionResult> execute({
    required String chain,
    Stopwatch? clock,
    Duration? admissionLimit,
  }) async {
    if (chain != 'bitcoin' && chain != 'liquid') {
      return const BackgroundTaskExecutionResult.permanentFailure();
    }
    final stopwatch = clock ?? (Stopwatch()..start());
    var retry = false;
    var permanent = false;
    var newIncoming = 0;
    var succeeded = 0;
    var retried = 0;
    var permanentlyFailed = 0;
    final eligibleJobs = jobs.where((job) => job.key.chain == chain).toList();
    final registrations = [
      for (final job in eligibleJobs)
        (key: job.key, revision: job.queueRevision),
    ];
    final jobsByKey = {for (final job in eligibleJobs) job.key: job};
    final observations = <NotificationTopicObservation>[];
    final handled = <WalletNetworkKey>{};
    var claimed = 0;
    var budgetReached = false;

    bool budgetSpent() {
      final budget = admissionLimit ?? runBudget;
      return budget != null && stopwatch.elapsed >= budget;
    }

    // A wallet is claimed only when a worker is about to start it: a claim
    // counts as an attempt, so one claimed but never started would be backed
    // off, and keep its lease, if the platform stops the run.
    Future<WalletSyncJobClaim?> claimNext() async {
      if (claimed >= maxJobsPerRun) return null;
      if (budgetSpent()) {
        budgetReached = true;
        return null;
      }
      claimed++;
      final claims = await queue.reconcileAndClaim(
        registrations,
        chain: chain,
        maxJobs: 1,
        excluding: handled,
      );
      if (claims.isEmpty) {
        claimed--;
        return null;
      }
      handled.add(claims.single.key);
      return claims.single;
    }

    Future<void> runWorker() async {
      while (true) {
        final claim = await claimNext();
        if (claim == null) break;
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
            case Err(failure: InitialScanRequiredFailure()):
              // A whole-history scan does not fit a background run: the
              // foreground does it, then this wallet is synced here again.
              // Settled like a success, so no backoff outlives that scan and
              // the wallet keeps its normal turn instead of being retried
              // ahead of the others.
              final completed = await queue.completeSuccess(claim);
              if (renewalFailed || !completed) retry = true;
              _safeLog(
                WalletSyncLogLevel.fine,
                'Wallet sync skipped: chain=$chain '
                'reason=initial_scan_in_foreground',
              );
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
                observations.add(_observationFor(job, value));
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

    final workerCount = [
      maxConcurrentJobs,
      maxJobsPerRun,
      eligibleJobs.length,
    ].reduce(min);
    await Future.wait(List.generate(workerCount, (_) => runWorker()));
    if (budgetReached) {
      _safeLog(
        WalletSyncLogLevel.fine,
        'Wallet sync run budget reached: chain=$chain',
      );
    }
    _safeLog(
      WalletSyncLogLevel.fine,
      'Wallet sync queue completion: chain=$chain claimed=$claimed '
      'succeeded=$succeeded retried=$retried permanent=$permanentlyFailed '
      'new_incoming=$newIncoming elapsed_ms=${stopwatch.elapsedMilliseconds}',
    );

    final completedObservations = observations;
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
            'category=${_notificationCategory(failure)}',
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
          'category=${_notificationCategory(failure)}',
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

  /// A short fixed label. Class names are not used: the support log redacts
  /// any run of 32 or more letters, which some of them are.
  static String _notificationCategory(NotificationsFailure failure) =>
      switch (failure) {
        NotificationsStorageFailure() => 'storage',
        NotificationsGatewayFailure() => 'gateway',
        NotificationsPermissionDeniedFailure() => 'permission_denied',
        NotificationsClaimLostFailure() => 'claim_lost',
        UnknownNotificationDestinationFailure() => 'unknown_destination',
        InvalidNotificationPayloadFailure() => 'invalid_payload',
      };

  /// A short fixed label: the support log redacts runs of 32 or more letters,
  /// which some failure class names are.
  static String _category(WalletTransactionSyncFailure failure) =>
      switch (failure) {
        SourceFailure(:final reason) => 'SourceFailure.${reason.name}',
        SnapshotNotInitializedFailure() => 'snapshot_not_initialized',
        WalletRegistrationMismatchFailure() => 'registration_mismatch',
        WalletSourceStateMissingFailure() => 'source_state_missing',
        WalletSourceStateIncompatibleFailure() => 'source_state_incompatible',
        DeletedWalletFailure() => 'deleted_wallet',
        SourceStorageFailure() => 'source_storage',
        SourceObservationMismatchFailure() => 'observation_mismatch',
        ExtractionFailure() => 'extraction',
        CoordinationTimeoutFailure() => 'coordination_timeout',
        DeletionFailure() => 'deletion',
        SnapshotExpiredFailure() => 'snapshot_expired',
        InvalidPaginationFailure() => 'invalid_pagination',
        InvalidWalletBirthdayFailure() => 'invalid_birthday',
        InitialScanRequiredFailure() => 'initial_scan_required',
        WalletSyncDeferredFailure() => 'deferred',
        CbfNoPeersFailure() => 'cbf_no_peers',
        CbfTorUnavailableFailure() => 'cbf_tor_unavailable',
        CbfTransactionNotRecoverableFailure() ||
        CbfBroadcastNotRelayedFailure() => 'cbf_not_relayed',
        CbfNodeDidNotStopFailure() => 'cbf_not_stopped',
        CbfRemoteLookupForbiddenFailure() => 'cbf_remote_forbidden',
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
    SnapshotExpiredFailure() ||
    CbfNoPeersFailure() ||
    CbfTorUnavailableFailure() ||
    CbfTransactionNotRecoverableFailure() ||
    CbfBroadcastNotRelayedFailure() ||
    CbfNodeDidNotStopFailure() => onRetry(),
    SnapshotNotInitializedFailure() ||
    WalletRegistrationMismatchFailure() ||
    WalletSourceStateMissingFailure() ||
    WalletSourceStateIncompatibleFailure() ||
    DeletedWalletFailure() ||
    SourceFailure(reason: SourceFailureReason.rejected) ||
    SourceObservationMismatchFailure() ||
    ExtractionFailure() ||
    DeletionFailure() ||
    InvalidWalletBirthdayFailure() ||
    InvalidPaginationFailure() ||
    CbfRemoteLookupForbiddenFailure() => onPermanent(),
    // Neither: the foreground scans it, then background runs resume.
    InitialScanRequiredFailure() || WalletSyncDeferredFailure() => null,
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
    // Nothing to retry: hidden notifications are dropped, never replayed
    // once the user grants the permission.
    NotificationsPermissionDeniedFailure() => null,
  };
}
