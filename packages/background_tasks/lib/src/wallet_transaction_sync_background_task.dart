import 'dart:async';
import 'dart:convert';

import 'package:bull_logger/bull_logger.dart' show log;
import 'package:crypto/crypto.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

import 'data/shared_preferences_background_sync_interval_repository.dart';
import 'domain/background_sync_interval.dart';
import 'domain/repositories/background_sync_interval_repository.dart';
import 'background_task_execution_result.dart';
import 'background_task_logger.dart';
import 'background_wallet_sync.dart';
import 'read_wallet_sync_jobs.dart';
import 'domain/background_tasks_failure.dart';
import 'domain/repositories/wallet_sync_job_queue_repository.dart';
import 'domain/wallet_sync_chain.dart';
import 'domain/wallet_sync_job_claim.dart';

typedef NotificationCopy = ({String title, String body});
typedef NotificationCopyBuilder =
    NotificationCopy Function(int count, WalletSyncChain chain);

/// Admission and retry policy only; native writer ownership belongs to the
/// injected port. No Secrets, native handles, widgets or application locator.
final class WalletTransactionSyncBackgroundTask {
  final BackgroundWalletSync writer;
  final WalletRevisionReaderPort revisions;
  final List<WalletKey> keys;
  final WalletSyncJobQueueRepository queue;
  final NotificationsFacade? notifications;
  final NotificationCopyBuilder copy;
  final int maxJobsPerChain;
  final Duration? runBudget;
  final Duration renewalInterval;
  final BackgroundSyncIntervalRepository intervals;
  final BackgroundTaskLogger _sink;

  WalletTransactionSyncBackgroundTask({
    required this.writer,
    required this.revisions,
    required Iterable<WalletKey> keys,
    required this.queue,
    required this.notifications,
    required this.copy,
    this.maxJobsPerChain = 2,
    BackgroundTaskLogger? logSink,
    this.runBudget,
    this.renewalInterval = const Duration(minutes: 5),
    // Until phase B, lib/features/wallet constructs this task without it.
    this.intervals = const SharedPreferencesBackgroundSyncIntervalRepository(),
  }) : keys = List.unmodifiable(keys),
       _sink = logSink ?? LoggerBackgroundTaskLogger(log) {
    final budget = runBudget;
    if (maxJobsPerChain <= 0 ||
        renewalInterval <= Duration.zero ||
        renewalInterval >= queue.leaseDuration ||
        (budget != null && budget < Duration.zero)) {
      throw ArgumentError('Invalid background admission policy');
    }
    if (this.keys.toSet().length != this.keys.length) {
      throw ArgumentError('Duplicate wallet keys');
    }
  }

  /// The platform-started clock includes bootstrap time. Bitcoin admissions
  /// consume at most half the budget; an admitted native operation is awaited
  /// even if it exceeds the budget. Queue timers never release native locks.
  Future<BackgroundTaskExecutionResult> executeAll({Stopwatch? clock}) async {
    final elapsed = clock ?? (Stopwatch()..start());
    var retry = false;
    final admission = _RunAdmission();
    for (final chain in WalletSyncChain.values) {
      final budget = runBudget;
      final result = await _execute(
        chain: chain,
        clock: elapsed,
        admission: admission,
        admissionLimit: chain == WalletSyncChain.bitcoin && budget != null
            ? budget ~/ 2
            : budget,
      );
      retry |= result.shouldRetry;
      if (admission.stopped) break;
    }
    return retry
        ? const BackgroundTaskExecutionResult.retry()
        : const BackgroundTaskExecutionResult.success();
  }

  Future<BackgroundTaskExecutionResult> _execute({
    required WalletSyncChain chain,
    required _RunAdmission admission,
    Stopwatch? clock,
    Duration? admissionLimit,
  }) async {
    final notifications = this.notifications;
    final elapsed = clock ?? (Stopwatch()..start());
    final budget = admissionLimit ?? runBudget;
    bool spent() => budget != null && elapsed.elapsed >= budget;
    var retry = false;
    final handled = <WalletKey>{};
    var reportedUnavailable = false;
    for (var count = 0; count < maxJobsPerChain && !spent(); count++) {
      if (await _optedOut(admission)) break;
      // Refresh the authoritative stamp before EVERY admission, so this run
      // cannot overwrite a successful writer's new stamp with an older list.
      final read = await readWalletSyncJobs(
        keys.where((key) => walletSyncChain(key) == chain),
        revisions,
      );
      if (read case Err()) {
        _log(
          BackgroundLogLevel.warning,
          'Background admission failed reason=revision_read',
        );
        return const BackgroundTaskExecutionResult.retry();
      }
      final jobs =
          (read as Ok<WalletSyncJobSelection, TransactionSyncFailure>).value;
      if (jobs.unavailable.isNotEmpty) {
        retry = true;
        if (!reportedUnavailable) {
          _log(
            BackgroundLogLevel.warning,
            'Background wallets deferred: chain=${chain.name} unavailable=${jobs.unavailable.length}',
          );
          reportedUnavailable = true;
        }
      }
      if (spent()) break;
      final List<WalletSyncJobClaim> claims;
      switch (await queue.reconcileAndClaim(
        jobs.ready,
        unavailable: jobs.unavailable,
        chain: chain,
        maxJobs: 1,
        excluding: handled,
      )) {
        case Err():
          _log(
            BackgroundLogLevel.warning,
            'Background admission failed reason=queue_storage',
          );
          return const BackgroundTaskExecutionResult.retry();
        case Ok(:final value):
          claims = value;
      }
      if (claims.isEmpty) break;
      final claim = claims.single;
      final bool stop;
      try {
        stop = await _optedOut(admission) || spent();
      } catch (_) {
        // A failed preference read must not leave a claim without a writer.
        await _release(claim);
        rethrow;
      }
      if (stop) {
        await _release(claim);
        break;
      }
      handled.add(claim.key);
      final operationClock = Stopwatch()..start();
      _log(
        BackgroundLogLevel.fine,
        'Background job admitted: chain=${chain.name} network=${claim.key.network.env.name}',
      );
      var leaseLost = false;
      var outcome = 'retry';
      Future<void>? renewing;
      Future<void> renew() async {
        try {
          final renewed = await queue.renew(claim);
          if (renewed case Err(
            failure: BackgroundTasksStorageFailure(),
          ) when !leaseLost) {
            _log(
              BackgroundLogLevel.warning,
              'Background lease renewal failed reason=storage',
            );
          }
          if (renewed case Err()) leaseLost = true;
        } finally {
          renewing = null;
        }
      }

      final timer = Timer.periodic(renewalInterval, (_) {
        renewing ??= renew();
      });
      try {
        final sync = await writer.synchronize(
          claim.key,
          allowInitialScan: false,
          // Pinned bdk_chain discovery can miss revealed addresses beyond the stop gap.
          // Remove this workaround once the binding pins bdk_chain >= 0.23.4: https://github.com/bitcoindevkit/bdk/pull/2222.
          discover: false,
        );
        switch (sync) {
          case Err(failure: BackgroundSyncNeedsRepairFailure(:final revision)):
            outcome = 'deferred';
            _log(
              BackgroundLogLevel.fine,
              'Background job deferred: category=needs_repair revision=${revision.revision} generation=${revision.generation}',
            );
            if (revision.key != claim.key) {
              throw StateError('Writer returned a foreign revision');
            }
            if (await queue.completeFailure(
                  claim,
                  permanent: true,
                  failedRevision: revision,
                )
                case Err()) {
              leaseLost = true;
            }
          case Err(
            failure: final refused &&
                (BackgroundSyncUnsupportedNetworkFailure() ||
                    BackgroundSyncUnauthorizedNetworkFailure()),
          ):
            outcome = 'deferred';
            _log(
              BackgroundLogLevel.fine,
              'Background job deferred: category=${refused is BackgroundSyncUnauthorizedNetworkFailure ? 'authorization' : 'unsupported_network'}',
            );
            if (await queue.completeFailure(claim, permanent: true)
                case Err()) {
              leaseLost = true;
            }
          case Err(failure: BackgroundSyncInitialScanRequiredFailure()):
            outcome = 'deferred';
            _log(
              BackgroundLogLevel.fine,
              'Background job deferred: category=initial_scan',
            );
            if (await queue.completeSuccess(claim) case Err()) leaseLost = true;
          case Err(:final failure):
            _log(
              BackgroundLogLevel.fine,
              'Background job retry: category=${failure is BackgroundSyncBusyFailure
                  ? 'busy'
                  : failure is BackgroundSyncUnavailableFailure
                  ? failure.reason.name
                  : 'connection'}',
            );
            retry = true;
            if (await queue.completeFailure(claim, permanent: false)
                case Err()) {
              leaseLost = true;
            }
          case Ok(:final value):
            outcome = 'success';
            if (value.revision.key != claim.key) {
              throw StateError('Writer returned a foreign revision');
            }
            _log(
              BackgroundLogLevel.fine,
              'Background job committed: revision=${value.revision.revision} generation=${value.revision.generation} incoming=${value.incomingTxids?.length ?? 'unknown'}',
            );
            final incoming = value.incomingTxids;
            if (incoming == null || notifications == null) {
              if (await queue.completeSuccess(claim) case Err()) {
                leaseLost = true;
              }
              break;
            }
            // Observations are best effort after native commit; later history
            // replays an interrupted handoff without degrading the sync result.
            try {
              final reconciled = await notifications.recordBackground(
                WalletPaymentNotificationIdentity.observation(
                  claim.key,
                  incoming,
                ),
                (ids) {
                  final text = copy(ids.length, chain);
                  return LocalNotification(
                    eventId: sha256
                        .convert(utf8.encode((ids.toList()..sort()).join('|')))
                        .toString(),
                    title: text.title,
                    body: text.body,
                    createdAt: value.completedAt,
                  );
                },
              );
              if (reconciled is Err) {
                _log(
                  BackgroundLogLevel.warning,
                  'Background observation failed: category=notification_persistence',
                );
              }
            } on Exception {
              _log(
                BackgroundLogLevel.warning,
                'Background observation failed: category=notification_persistence',
              );
            }
            if (await queue.completeSuccess(claim) case Err()) {
              leaseLost = true;
            }
        }
      } on Exception {
        outcome = 'retry';
        _log(
          BackgroundLogLevel.warning,
          'Background job retry: category=operation_exception',
        );
        retry = true;
        if (await queue.completeFailure(claim, permanent: false) case Err()) {
          leaseLost = true;
        }
      } finally {
        timer.cancel();
        await renewing;
        _log(
          BackgroundLogLevel.fine,
          'Background job finished: chain=${chain.name} network=${claim.key.network.env.name} outcome=$outcome elapsed_ms=${operationClock.elapsedMilliseconds} lease_lost=$leaseLost',
        );
      }
      if (leaseLost) {
        _log(
          BackgroundLogLevel.warning,
          'Background admission stopped: category=claim_lost',
        );
        admission.stopped = true;
        return const BackgroundTaskExecutionResult.retry();
      }
    }
    if (admission.stopped) return const BackgroundTaskExecutionResult.success();
    _log(
      BackgroundLogLevel.fine,
      'Background admission stopped reason=${spent()
          ? 'budget'
          : handled.length >= maxJobsPerChain
          ? 'limit'
          : 'empty'} chain=${chain.name} elapsed_ms=${elapsed.elapsed.inMilliseconds} budget_ms=${budget?.inMilliseconds ?? 'unlimited'} admitted=${handled.length}',
    );
    final delivered = await notifications?.deliverPending();
    if (delivered case Err(
      failure: final failure,
    ) when failure is! NotificationsPermissionDeniedFailure) {
      _log(
        BackgroundLogLevel.warning,
        'Background notifications retry: category=delivery',
      );
      retry = true;
    }
    return retry
        ? const BackgroundTaskExecutionResult.retry()
        : const BackgroundTaskExecutionResult.success();
  }

  Future<void> _release(WalletSyncJobClaim claim) async {
    if (await queue.release(claim) case Err()) {
      _log(BackgroundLogLevel.warning, 'Background claim release failed');
    }
  }

  Future<bool> _optedOut(_RunAdmission admission) async {
    if (await intervals.read() != BackgroundSyncInterval.off) {
      return false;
    }
    admission.stopped = true;
    _log(
      BackgroundLogLevel.fine,
      'Background admission stopped: category=opt_out',
    );
    return true;
  }

  void _log(BackgroundLogLevel level, String message) {
    try {
      _sink.write(level, message);
    } on Exception {
      // Diagnostics must not change a completed writer operation.
    }
  }
}

final class _RunAdmission {
  bool stopped = false;
}
