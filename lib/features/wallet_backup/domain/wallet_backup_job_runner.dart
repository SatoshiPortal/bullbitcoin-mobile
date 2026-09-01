import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

typedef PublishWalletBackup =
    Future<Result<void, WalletBackupFailure>> Function();

/// The single queue every remote Bull backup job runs in.
///
/// Publish, recover, import, delete remote, and change server are the only
/// jobs, and exactly one of them touches the server at a time. There is no
/// separate lease, deferred completer, or lifecycle tail: a job either owns
/// the runner or waits for it (spec 18, F8).
///
/// Publication is additionally coalesced. Triggers arriving while a
/// publication runs collapse into one further pass, and the durable revisions
/// decide whether that pass still has work to do.
final class WalletBackupJobRunner {
  final PublishWalletBackup _publish;
  final DateTime Function() _now;

  Future<void> _queue = Future.value();
  Completer<Result<void, WalletBackupFailure>>? _publication;
  bool _publishAgain = false;
  DateTime? _notBefore;
  bool _disposed = false;

  WalletBackupJobRunner({required this._publish, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Runs [job] alone, after everything already queued.
  ///
  /// A rate-limited server closes the gate for the interval it asked for, and
  /// jobs reaching the runner before then fail without a request. The gate is
  /// deliberately in memory only (decision 8).
  @useResult
  Future<Result<T, WalletBackupFailure>> run<T>(
    Future<Result<T, WalletBackupFailure>> Function() job,
  ) => _enqueue(() => _gated(job));

  /// Requests a publication, joining one that is already queued or running.
  ///
  /// The returned future completes with the result of the last pass, so a
  /// caller that triggered work during an earlier pass still learns whether
  /// its own change reached the server.
  Future<Result<void, WalletBackupFailure>> requestPublish() {
    if (_disposed) return Future.value(const Err(_disposedFailure));
    final pending = _publication;
    _publishAgain = true;
    if (pending != null) return pending.future;

    final completer = Completer<Result<void, WalletBackupFailure>>();
    _publication = completer;
    unawaited(_enqueue(_drainPublications));
    return completer.future;
  }

  /// Drains anything already queued, so a caller can observe a settled runner.
  Future<void> settle() => _enqueue<void>(() async {});

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _queue;
    } on Exception {
      // Every job reports its own failure to its own caller.
    }
    final pending = _publication;
    _publication = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(const Err(_disposedFailure));
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Result<void, WalletBackupFailure>> _drainPublications() async {
    final completer = _publication!;
    Result<void, WalletBackupFailure> result = const Ok(null);
    try {
      while (_publishAgain && !_disposed) {
        _publishAgain = false;
        result = await _gated(_publish);
      }
    } catch (error, trace) {
      _publication = null;
      if (!completer.isCompleted) completer.completeError(error, trace);
      rethrow;
    }
    _publication = null;
    if (!completer.isCompleted) completer.complete(result);
    return result;
  }

  Future<Result<T, WalletBackupFailure>> _gated<T>(
    Future<Result<T, WalletBackupFailure>> Function() job,
  ) async {
    if (_disposed) return const Err(_disposedFailure);
    final notBefore = _notBefore;
    if (notBefore != null) {
      final remaining = notBefore.difference(_now().toUtc());
      if (!remaining.isNegative && remaining != Duration.zero) {
        return Err(WalletBackupRateLimitedFailure(remaining));
      }
      _notBefore = null;
    }
    final result = await job();
    if (result case Err(
      failure: WalletBackupRateLimitedFailure(:final retryAfter),
    )) {
      _notBefore = _now().toUtc().add(retryAfter);
    }
    return result;
  }
}

const _disposedFailure = WalletBackupUnexpectedFailure(
  'wallet backup job runner disposed',
);
