import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notifications_usecase.dart';

/// Self-healing SP notification stream. The singleton session can be recycled
/// out from under a listener (a wallet-side full refresh after a network change
/// disposes it); when that closes the underlying stream, this re-establishes
/// the session and re-subscribes, so the UI never goes dead.
///
/// The re-subscribe policy lives here (not in the cubit): a backoff + flap cap
/// so a stream that closes right after each re-establish can't busy-loop. A
/// recycle after a healthy stretch re-establishes at once.
class SpNotificationsWatcher {
  final WatchSpNotificationsUsecase _watchSpNotificationsUsecase;
  final EnsureSpSessionUsecase _ensureSpSessionUsecase;

  SpNotificationsWatcher({
    required this._watchSpNotificationsUsecase,
    required this._ensureSpSessionUsecase,
  });

  static const int _maxRapidResubscribes = 5;
  static const Duration _resubscribeBackoff = Duration(seconds: 2);
  static const Duration _resubscribeHealthyGap = Duration(seconds: 30);

  StreamController<SpNotification>? _controller;
  StreamSubscription<SpNotification>? _sourceSub;
  Timer? _resubscribeTimer;
  int _rapidResubscribes = 0;
  DateTime? _lastResubscribeAt;
  void Function()? _onReconnect;

  /// Continuous notification stream that survives session recycles. [onReconnect]
  /// fires after each successful re-establish (not the first subscribe) so the
  /// caller can reload wallet data the new session exposes.
  Stream<SpNotification> watch({required void Function() onReconnect}) {
    _onReconnect = onReconnect;
    final controller = _controller ??=
        StreamController<SpNotification>.broadcast(onListen: _subscribe);
    return controller.stream;
  }

  void _subscribe() {
    unawaited(_sourceSub?.cancel());
    _sourceSub = _watchSpNotificationsUsecase.execute().listen(
      (n) => _controller?.add(n),
      onDone: _reestablish,
      onError: (Object e) {
        log.warning('SpNotificationsWatcher: notification stream error: $e');
        _reestablish();
      },
    );
  }

  void _reestablish() {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    final now = DateTime.now();
    final previous = _lastResubscribeAt;
    _lastResubscribeAt = now;
    // A recycle after a healthy stretch (e.g. a network-change dispose) is a
    // one-off: re-establish at once and forget earlier attempts.
    if (previous == null || now.difference(previous) > _resubscribeHealthyGap) {
      _rapidResubscribes = 0;
      unawaited(_establishAndResubscribe());
      return;
    }
    // Rapid repeats mean the backend is flapping. Cap the attempts and space
    // them out so a stream that closes right after every re-establish can't
    // busy-loop.
    _rapidResubscribes++;
    if (_rapidResubscribes > _maxRapidResubscribes) {
      log.warning(
        'SpNotificationsWatcher: notification stream flapping; '
        'stopped re-subscribing',
      );
      return;
    }
    _resubscribeTimer?.cancel();
    _resubscribeTimer = Timer(_resubscribeBackoff, () {
      final c = _controller;
      if (c == null || c.isClosed) return;
      unawaited(_establishAndResubscribe());
    });
  }

  Future<void> _establishAndResubscribe() async {
    try {
      // A genuinely revoked / not-set-up wallet returns null; do NOT
      // re-subscribe (a dead session's stream would close at once and loop).
      final wallet = await _ensureSpSessionUsecase.execute();
      final controller = _controller;
      if (controller == null || controller.isClosed) return;
      if (wallet == null) return;
      _subscribe();
      _onReconnect?.call();
    } catch (e) {
      log.warning('SpNotificationsWatcher: re-establish failed: $e');
    }
  }

  Future<void> dispose() async {
    _resubscribeTimer?.cancel();
    await _sourceSub?.cancel();
    _sourceSub = null;
    final controller = _controller;
    _controller = null;
    await controller?.close();
  }
}
