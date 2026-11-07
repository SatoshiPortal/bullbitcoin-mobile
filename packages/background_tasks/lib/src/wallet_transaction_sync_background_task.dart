import 'dart:async';
import 'dart:convert';

import 'package:bull_logger/bull_logger.dart' show log;
import 'package:crypto/crypto.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

import 'background_task_execution_result.dart';
import 'background_task_logger.dart';
import 'background_wallet_sync.dart';
import 'read_wallet_sync_jobs.dart';
import 'sqlite_wallet_sync_job_queue.dart';

typedef NotificationCopy = ({String title, String body});
typedef NotificationCopyBuilder =
    NotificationCopy Function(int count, WalletSyncChain chain);

/// Admission and retry policy only; native writer ownership belongs to the
/// injected port. No Secrets, native handles, widgets or application locator.
final class WalletTransactionSyncBackgroundTask {
  final BackgroundWalletSync writer;
  final WalletRevisionReader revisions;
  final List<WalletKey> keys;
  final WalletSyncJobQueue queue;
  final NotificationsFacade? notifications;
  final NotificationCopyBuilder copy;
  final int maxJobsPerChain;
  final Duration? runBudget;
  final Duration renewalInterval;
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
      // Refresh the authoritative stamp before EVERY admission, so this run
      // cannot overwrite a successful writer's new stamp with an older list.
      final read = await readWalletSyncJobs(
        keys.where((key) => walletSyncChain(key) == chain),
        revisions,
      );
      if (read case Err()) return const BackgroundTaskExecutionResult.retry();
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
      final claims = await queue.reconcileAndClaim(
        jobs.ready,
        unavailable: jobs.unavailable,
        chain: chain,
        maxJobs: 1,
        excluding: handled,
      );
      if (claims.isEmpty) break;
      final claim = claims.single;
      if (spent()) {
        await queue.release(claim);
        break;
      }
      handled.add(claim.key);
      final operationClock = Stopwatch()..start();
      _log(
        BackgroundLogLevel.fine,
        'Background job admitted: chain=${chain.name} network=${claim.key.network.env.name}',
      );
      var leaseLost = false;
      Future<void>? renewing;
      Future<void> renew() async {
        try {
          if (!await queue.renew(claim)) leaseLost = true;
        } on Exception catch (error) {
          if (!leaseLost) {
            _log(
              BackgroundLogLevel.warning,
              'Background lease renewal failed type=${error.runtimeType}',
            );
          }
          leaseLost = true;
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
        );
        switch (sync) {
          case Err(failure: BackgroundSyncNeedsRepairFailure(:final revision)):
            _log(
              BackgroundLogLevel.warning,
              'Background job deferred: category=needs_repair revision=${revision.revision} generation=${revision.generation}',
            );
            if (revision.key != claim.key) {
              throw StateError('Writer returned a foreign revision');
            }
            if (!await queue.completeFailure(
              claim,
              permanent: true,
              failedRevision: revision,
            )) {
              leaseLost = true;
            }
          case Err(failure: BackgroundSyncUnsupportedNetworkFailure()):
            _log(
              BackgroundLogLevel.warning,
              'Background job deferred: category=unsupported_network',
            );
            if (!await queue.completeFailure(claim, permanent: true)) {
              leaseLost = true;
            }
          case Err(failure: BackgroundSyncInitialScanRequiredFailure()):
            _log(
              BackgroundLogLevel.fine,
              'Background job deferred: category=initial_scan',
            );
            if (!await queue.completeSuccess(claim)) leaseLost = true;
          case Err(:final failure):
            _log(
              BackgroundLogLevel.warning,
              'Background job retry: category=${failure is BackgroundSyncBusyFailure ? 'busy' : 'connection'}',
            );
            retry = true;
            if (!await queue.completeFailure(claim, permanent: false)) {
              leaseLost = true;
            }
          case Ok(:final value):
            if (value.revision.key != claim.key) {
              throw StateError('Writer returned a foreign revision');
            }
            _log(
              BackgroundLogLevel.fine,
              'Background job committed: revision=${value.revision.revision} generation=${value.revision.generation} incoming=${value.incomingTxids?.length ?? 0}',
            );
            final incoming = value.incomingTxids;
            if (incoming == null || notifications == null) {
              if (!await queue.completeSuccess(claim)) leaseLost = true;
              break;
            }
            // Observations are best effort after native commit; later history
            // replays an interrupted handoff without degrading the sync result.
            try {
              final reconciled = await notifications.reconcileTopicsAndEnqueue(
                [
                  NotificationTopicObservation(
                    WalletPaymentNotificationIdentity.topicId(claim.key),
                    [
                      for (final txid in incoming)
                        WalletPaymentNotificationIdentity.event(
                          claim.key,
                          txid,
                          observedAt: value.completedAt,
                        ),
                    ],
                  ),
                ],
                (events) {
                  final ids = events.map((e) => e.eventId).toList()..sort();
                  final text = copy(events.length, chain);
                  return LocalNotification(
                    eventId: sha256
                        .convert(utf8.encode(ids.join('|')))
                        .toString(),
                    title: text.title,
                    body: text.body,
                    destination: NotificationDestination.walletHome,
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
            } on Object {
              _log(
                BackgroundLogLevel.warning,
                'Background observation failed: category=notification_persistence',
              );
            }
            if (!await queue.completeSuccess(claim)) {
              leaseLost = true;
            }
        }
      } on Exception catch (error) {
        _log(
          BackgroundLogLevel.warning,
          'Background job retry: category=operation_exception type=${error.runtimeType}',
        );
        retry = true;
        if (!await queue.completeFailure(claim, permanent: false)) {
          leaseLost = true;
        }
      } finally {
        timer.cancel();
        await renewing;
        _log(
          BackgroundLogLevel.fine,
          'Background job finished: chain=${chain.name} elapsed_ms=${operationClock.elapsedMilliseconds} lease_lost=$leaseLost',
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
