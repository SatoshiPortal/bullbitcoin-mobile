import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import 'ports/background_task_logger_port.dart';
import 'background_sync_interval.dart';
import 'background_task_execution_result.dart';
import 'background_tasks_failure.dart';
import 'ports/background_wallet_sync_port.dart';
import 'ports/payment_announcement_port.dart';
import 'read_wallet_sync_jobs.dart';
import 'repositories/background_sync_interval_repository.dart';
import 'repositories/wallet_sync_job_queue_repository.dart';
import 'wallet_sync_chain.dart';
import 'wallet_sync_job_claim.dart';

/// One background run over the catalog: per chain, admit a job, sync it,
/// settle it, then deliver the announcements. Admission and retry policy
/// only; native writer ownership belongs to [BackgroundWalletSyncPort].
final class RunWalletSyncJobsUsecase {
  final BackgroundWalletSyncPort _wallets;
  final WalletRevisionReaderPort _revisions;
  final List<WalletKey> _keys;
  final WalletSyncJobQueueRepository _queue;
  final BackgroundSyncIntervalRepository _intervals;

  /// Null when notifications are unavailable for this run.
  final PaymentAnnouncementPort? _announcements;
  final BackgroundTaskLoggerPort _logger;
  final int maxJobsPerChain;
  final Duration? runBudget;
  final Duration renewalInterval;

  RunWalletSyncJobsUsecase({
    required this._wallets,
    required this._revisions,
    required Iterable<WalletKey> keys,
    required WalletSyncJobQueueRepository queue,
    required this._intervals,
    required this._announcements,
    required this._logger,
    this.maxJobsPerChain = 2,
    this.runBudget,
    this.renewalInterval = const Duration(minutes: 5),
  }) : _keys = List.unmodifiable(keys),
       _queue = queue {
    final budget = runBudget;
    if (maxJobsPerChain <= 0 ||
        renewalInterval <= Duration.zero ||
        renewalInterval >= queue.leaseDuration ||
        (budget != null && budget < Duration.zero)) {
      throw ArgumentError('Invalid background admission policy');
    }
    if (_keys.toSet().length != _keys.length) {
      throw ArgumentError('Duplicate wallet keys');
    }
  }

  /// The platform-started [clock] includes bootstrap time. Bitcoin admissions
  /// consume at most half the budget; an admitted native operation is awaited
  /// even if it exceeds the budget. Queue timers never release native locks.
  Future<BackgroundTaskExecutionResult> execute({Stopwatch? clock}) async {
    final elapsed = clock ?? (Stopwatch()..start());
    final run = _Run();
    var retry = false;
    for (final chain in WalletSyncChain.values) {
      final budget = runBudget;
      retry |= await _runChain(
        chain,
        run,
        elapsed,
        chain == WalletSyncChain.bitcoin && budget != null
            ? budget ~/ 2
            : budget,
      );
      if (run.stopped) break;
    }
    return retry
        ? const BackgroundTaskExecutionResult.retry()
        : const BackgroundTaskExecutionResult.success();
  }

  /// Returns whether the run should be retried.
  Future<bool> _runChain(
    WalletSyncChain chain,
    _Run run,
    Stopwatch elapsed,
    Duration? budget,
  ) async {
    bool spent() => budget != null && elapsed.elapsed >= budget;
    var retry = false;
    final handled = <WalletKey>{};
    var reportedUnavailable = false;
    for (var count = 0; count < maxJobsPerChain && !spent(); count++) {
      // 1. Admission.
      if (await _optedOut(run)) break;
      // Refresh the authoritative stamp before EVERY admission, so this run
      // cannot overwrite a successful writer's new stamp with an older list.
      final read = await readWalletSyncJobs(
        _keys.where((key) => walletSyncChain(key) == chain),
        _revisions,
      );
      final WalletSyncJobSelection jobs;
      switch (read) {
        case Err():
          _log(
            BackgroundLogLevel.warning,
            'Background admission failed reason=revision_read',
          );
          return true;
        case Ok(:final value):
          jobs = value;
      }
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
      final claims = switch (await _queue.reconcileAndClaim(
        jobs.ready,
        unavailable: jobs.unavailable,
        chain: chain,
        maxJobs: 1,
        excluding: handled,
      )) {
        Ok(:final value) => value,
        Err() => null,
      };
      if (claims == null) {
        _log(
          BackgroundLogLevel.warning,
          'Background admission failed reason=queue_storage',
        );
        return true;
      }
      if (claims.isEmpty) break;
      final claim = claims.single;
      final bool stop;
      try {
        stop = await _optedOut(run) || spent();
      } catch (_) {
        // A failed preference read must not leave a claim without a writer; the rethrow already retries.
        await _release(claim);
        rethrow;
      }
      if (stop) {
        final released = await _release(claim);
        // Opt-out keeps its policy; a claim still leased without a writer is retried.
        if (released case Err(
          failure: final failure,
        ) when failure is! BackgroundTasksClaimLostFailure && !run.stopped) {
          run.stopped = true;
          return true;
        }
        break;
      }
      handled.add(claim.key);
      _log(
        BackgroundLogLevel.fine,
        'Background job admitted: chain=${chain.name} network=${claim.key.network.env.name}',
      );

      // 2. One job, then 3. its settlement.
      final job = await _runJob(claim);
      retry |= job.retry;
      if (job.leaseLost) {
        _log(
          BackgroundLogLevel.warning,
          'Background admission stopped: category=${job.queueFailure is BackgroundTasksStorageFailure ? 'queue_storage' : 'claim_lost'}',
        );
        run.stopped = true;
        return true;
      }
    }
    if (run.stopped) return false;
    _log(
      BackgroundLogLevel.fine,
      'Background admission stopped reason=${spent()
          ? 'budget'
          : handled.length >= maxJobsPerChain
          ? 'limit'
          : 'empty'} chain=${chain.name} elapsed_ms=${elapsed.elapsed.inMilliseconds} budget_ms=${budget?.inMilliseconds ?? 'unlimited'} admitted=${handled.length}',
    );
    final delivered = await _announcements?.deliverPending();
    if (delivered case Err(failure: PaymentAnnouncementUnavailableFailure())) {
      _log(
        BackgroundLogLevel.warning,
        'Background notifications retry: category=delivery',
      );
      retry = true;
    }
    return retry;
  }

  /// Syncs the claimed wallet while renewing its lease, then settles it.
  Future<_Job> _runJob(WalletSyncJobClaim claim) async {
    final clock = Stopwatch()..start();
    var leaseLost = false;
    Future<void>? renewing;
    Future<void> renew() async {
      try {
        final renewed = await _queue.renew(claim);
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
    Result<BackgroundSyncOutcome, BackgroundSyncFailure>? sync;
    try {
      sync = await _wallets.synchronize(
        claim.key,
        allowInitialScan: false,
        // Pinned bdk_chain discovery can miss revealed addresses beyond the stop gap.
        // Remove this workaround once the binding pins bdk_chain >= 0.23.4: https://github.com/bitcoindevkit/bdk/pull/2222.
        discover: false,
      );
    } on Exception {
      _log(
        BackgroundLogLevel.warning,
        'Background job retry: category=operation_exception',
      );
    } finally {
      timer.cancel();
      await renewing;
    }
    final job = await _settle(claim, sync);
    if (leaseLost) job.leaseLost = true;
    _log(
      BackgroundLogLevel.fine,
      'Background job finished: chain=${walletSyncChain(claim.key).name} network=${claim.key.network.env.name} outcome=${job.outcome} elapsed_ms=${clock.elapsedMilliseconds} lease_lost=${job.leaseLost}',
    );
    return job;
  }

  /// Completes the claim from the sync result (null: the sync threw), then
  /// records what a committed sync saw.
  Future<_Job> _settle(
    WalletSyncJobClaim claim,
    Result<BackgroundSyncOutcome, BackgroundSyncFailure>? sync,
  ) async {
    switch (sync) {
      case null:
        return _Job.from(
          'retry',
          await _queue.completeFailure(claim, permanent: false),
          retry: true,
        );
      case Err(failure: BackgroundSyncNeedsRepairFailure(:final revision)):
        _log(
          BackgroundLogLevel.fine,
          'Background job deferred: category=needs_repair revision=${revision.revision} generation=${revision.generation}',
        );
        if (revision.key != claim.key) {
          throw StateError('Writer returned a foreign revision');
        }
        return _Job.from(
          'deferred',
          await _queue.completeFailure(
            claim,
            permanent: true,
            failedRevision: revision,
          ),
        );
      case Err(
        failure: final refused &&
            (BackgroundSyncUnsupportedNetworkFailure() ||
                BackgroundSyncUnauthorizedNetworkFailure()),
      ):
        _log(
          BackgroundLogLevel.fine,
          'Background job deferred: category=${refused is BackgroundSyncUnauthorizedNetworkFailure ? 'authorization' : 'unsupported_network'}',
        );
        return _Job.from(
          'deferred',
          await _queue.completeFailure(claim, permanent: true),
        );
      case Err(failure: BackgroundSyncInitialScanRequiredFailure()):
        _log(
          BackgroundLogLevel.fine,
          'Background job deferred: category=initial_scan',
        );
        return _Job.from('deferred', await _queue.completeSuccess(claim));
      case Err(:final failure):
        _log(
          BackgroundLogLevel.fine,
          'Background job retry: category=${switch (failure) {
            BackgroundSyncBusyFailure() => 'busy',
            BackgroundSyncUnavailableFailure(:final reason) => reason.name,
            _ => 'connection',
          }}',
        );
        return _Job.from(
          'retry',
          await _queue.completeFailure(claim, permanent: false),
          retry: true,
        );
      case Ok(:final value):
        if (value.revision.key != claim.key) {
          throw StateError('Writer returned a foreign revision');
        }
        _log(
          BackgroundLogLevel.fine,
          'Background job committed: revision=${value.revision.revision} generation=${value.revision.generation} incoming=${value.incomingTxids?.length ?? 'unknown'}',
        );
        final job = _Job.from('success', await _queue.completeSuccess(claim));
        // Best effort after the native commit: a later complete history
        // replays an interrupted handoff without degrading the sync result.
        if (await _announcements?.record(value) case Err()) {
          _log(
            BackgroundLogLevel.warning,
            'Background observation failed: category=notification_persistence',
          );
        }
        return job;
    }
  }

  Future<Result<void, BackgroundTasksFailure>> _release(
    WalletSyncJobClaim claim,
  ) async {
    final released = await _queue.release(claim);
    if (released case Err(:final failure)) {
      _log(
        BackgroundLogLevel.warning,
        'Background claim release failed: category=${failure is BackgroundTasksClaimLostFailure ? 'claim_lost' : 'queue_storage'}',
      );
    }
    return released;
  }

  Future<bool> _optedOut(_Run run) async {
    if (await _intervals.read() != BackgroundSyncInterval.off) return false;
    run.stopped = true;
    _log(
      BackgroundLogLevel.fine,
      'Background admission stopped: category=opt_out',
    );
    return true;
  }

  void _log(BackgroundLogLevel level, String message) {
    try {
      _logger.write(level, message);
    } on Exception {
      // Diagnostics must not change a completed writer operation.
    }
  }
}

final class _Run {
  bool stopped = false;
}

final class _Job {
  final String outcome;
  final bool retry;

  /// The completion failure, if the claim was lost or the queue failed.
  final BackgroundTasksFailure? queueFailure;

  /// The lease ended before the job did: admission stops for this run.
  bool leaseLost;

  _Job.from(
    this.outcome,
    Result<void, BackgroundTasksFailure> completion, {
    this.retry = false,
  }) : queueFailure = switch (completion) {
         Ok() => null,
         Err(:final failure) => failure,
       },
       leaseLost = completion is Err;
}
