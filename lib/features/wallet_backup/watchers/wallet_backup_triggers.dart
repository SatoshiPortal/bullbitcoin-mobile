import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_job_runner.dart';
import 'package:flutter/widgets.dart';

typedef RecordWalletBackupMutation =
    Future<Result<int, WalletBackupFailure>> Function();

/// Turns app events into runner requests, and nothing else.
///
/// A change stream does exactly two things (spec 18): make sure the mutation
/// is recorded durably, then ask the runner for a coalesced publication. All
/// serialization, queueing, and back-off live in the runner.
final class WalletBackupTriggers with WidgetsBindingObserver {
  /// Owners that already incremented the local revision inside the same
  /// database transaction as their write (decision 7). Nothing is recorded
  /// here; the change only asks for a publication.
  final Stream<void> recordedChanges;

  /// Owners that cannot record their own revision, because they do not commit
  /// through this database. Their change is recorded here before publishing.
  final Stream<void> unrecordedChanges;

  final Stream<ElectrumSyncResult> syncResults;
  final WalletBackupJobRunner runner;
  final RecordWalletBackupMutation recordMutation;

  final List<StreamSubscription<void>> _subscriptions = [];
  Future<void> _recording = Future.value();
  bool _started = false;
  bool _disposed = false;

  WalletBackupTriggers({
    required this.recordedChanges,
    required this.unrecordedChanges,
    required this.syncResults,
    required this.runner,
    required this.recordMutation,
  });

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _subscriptions.addAll([
      recordedChanges.listen(
        (_) => _requestPublish(),
        onError: _logStreamFailure,
      ),
      unrecordedChanges.listen(
        (_) => _recordThenPublish(),
        onError: _logStreamFailure,
      ),
      syncResults
          .where((result) => result.success)
          .listen((_) => _requestPublish(), onError: _logStreamFailure),
    ]);
    _requestPublish();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _requestPublish();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    try {
      await _recording;
    } on Exception {
      // Each recording task already logged its own failure.
    }
  }

  /// Recordings run one after another so a burst of changes cannot interleave
  /// read-modify-write increments.
  void _recordThenPublish() {
    if (_disposed) return;
    _recording = _recording.then((_) async {
      if (_disposed) return;
      if (await recordMutation() case Err(:final failure)) {
        log.warning(
          'Wallet backup could not record a local change',
          error: failure.runtimeType,
        );
        return;
      }
      _requestPublish();
    });
  }

  void _requestPublish() {
    if (_disposed) return;
    unawaited(
      runner
          .requestPublish()
          .then((result) {
            if (result case Err(
              :final failure,
            ) when failure is! WalletBackupDisabledFailure) {
              log.warning(
                'Automatic wallet backup did not complete',
                error: failure.runtimeType,
              );
            }
          })
          .catchError((Object error, StackTrace trace) {
            if (error is Error) Error.throwWithStackTrace(error, trace);
            log.warning(
              'Automatic wallet backup failed',
              error: error.runtimeType,
              trace: trace,
            );
          }),
    );
  }

  void _logStreamFailure(Object error, StackTrace trace) {
    if (error is Error) Error.throwWithStackTrace(error, trace);
    log.warning(
      'Wallet backup change stream failed',
      error: error.runtimeType,
      trace: trace,
    );
  }
}
