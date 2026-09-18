import 'dart:async';
import 'package:async/async.dart' show StreamGroup;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_job_status.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_publication.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

final class WalletBackupWatcher {
  static const _debounce = Duration(milliseconds: 500);
  static const _networkDelays = [5, 15, 30, 60];
  final PublishWalletBackupUsecase _publish;
  final WatchWalletBackupSnapshotUsecase _watchSnapshot;
  final WatchWalletBackupStateUsecase _watchState;
  final DateTime Function() _now;
  final _statuses = StreamController<WalletBackupJobStatus>.broadcast();
  WalletBackupJobStatus _status = const WalletBackupJobStatus();
  StreamSubscription<void>? _subscription;
  Timer? _timer;
  bool _active = false, _disposed = false, _running = false, _dirty = false;
  bool _waitingToRetry = false;
  int _networkAttempt = 0;

  WalletBackupWatcher({
    required this._publish,
    required this._watchSnapshot,
    required this._watchState,
    this._now = _utcNow,
  });

  WalletBackupJobStatus get status => _status;
  Stream<WalletBackupJobStatus> get statuses => _statuses.stream;

  void start() {
    if (_active || _disposed) return;
    _active = true;
    _subscription =
        StreamGroup.merge([
          _watchSnapshot.execute(),
          _watchState.execute(),
        ]).listen(
          (_) => _request(),
          onError: (Object _) {
            unawaited(stop());
            _emit(
              const WalletBackupJobStatus(
                result: Err(WalletBackupStorageFailure()),
              ),
            );
          },
        );
    _request();
  }

  void resume() {
    if (!_active) {
      start();
      return;
    }
    _request();
  }

  void _request() {
    if (!_active || _disposed) return;
    _dirty = true;
    if (_running || _waitingToRetry) return;
    _networkAttempt = 0;
    _schedule(_debounce);
  }

  void _schedule(Duration delay, {bool retry = false}) {
    _timer?.cancel();
    _waitingToRetry = retry;
    _timer = Timer(delay, () => unawaited(_run()));
  }

  Future<void> _run() async {
    _timer = null;
    _waitingToRetry = false;
    if (!_active || _disposed || _running) return;
    _dirty = false;
    _running = true;
    _emit(WalletBackupJobStatus(running: true, result: _status.result));
    final Result<WalletBackupPublication, WalletBackupFailure> result;
    try {
      result = await _publish.execute();
    } finally {
      _running = false;
    }
    if (!_active || _disposed) return;
    _emit(WalletBackupJobStatus(result: result));
    switch (result) {
      case Err(failure: WalletBackupRateLimitedFailure(:final retryAt)):
        final remaining = retryAt.difference(_now());
        _schedule(
          remaining > Duration.zero ? remaining : const Duration(seconds: 1),
          retry: true,
        );
      case Err(failure: WalletBackupNetworkFailure()):
        if (_networkAttempt < _networkDelays.length) {
          _schedule(
            Duration(seconds: _networkDelays[_networkAttempt++]),
            retry: true,
          );
        }
      case Err():
        break;
      case Ok(:final value):
        _networkAttempt = 0;
        if (_dirty || value == WalletBackupPublication.pending) {
          _schedule(_debounce);
        }
    }
  }

  void _emit(WalletBackupJobStatus status) {
    if (_disposed) return;
    _status = status;
    _statuses.add(status);
  }

  Future<void> stop() async {
    _active = false;
    _timer?.cancel();
    _timer = null;
    _waitingToRetry = false;
    _dirty = false;
    _networkAttempt = 0;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _statuses.close();
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
