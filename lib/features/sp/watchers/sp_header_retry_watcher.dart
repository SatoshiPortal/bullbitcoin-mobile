import 'dart:async';

import 'package:bb_mobile/features/sp/domain/usecases/resync_sp_listener_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Retry policy for a failed header initial-sync.
///
/// bwk reports a dropped header connection and a genuinely bad stored chain as
/// the same Failed event, so an initial-sync failure is retried before it is
/// shown as one. A restart that itself fails is silent upstream, so the timer
/// reschedules rather than waiting for an event that never arrives.
///
/// The policy lives here, not in the cubit: how many times to retry and how
/// long to wait are decisions about the backend, and the cubit only reflects
/// the outcome as a status.
class SpHeaderRetryWatcher {
  static const int maxRetries = 5;
  static const Duration backoff = Duration(seconds: 2);

  final ResyncSpListenerUsecase _resyncSpListenerUsecase;

  Timer? _timer;
  int _attempts = 0;
  // Bumped by reset(); a callback already past its await belongs to the old
  // generation and must not re-arm.
  int _generation = 0;

  SpHeaderRetryWatcher({required this._resyncSpListenerUsecase});

  /// Start retrying. [onGaveUp] fires once the attempts run out, so the caller
  /// can show the failure it was holding back.
  void start({required void Function() onGaveUp}) {
    _timer?.cancel();
    _timer = Timer(backoff, () async {
      if (_attempts >= maxRetries) {
        reset();
        onGaveUp();
        return;
      }
      final generation = _generation;
      _attempts++;
      if (await _resyncSpListenerUsecase.execute() case Err(:final failure)) {
        log.warning(
          'SpHeaderRetryWatcher: listener restart failed: ${failure.logMessage}',
        );
      }
      // A restart that works publishes Started, which resets the watcher; this
      // callback is then stale and must not re-arm.
      if (generation != _generation) return;
      // A restart that fails emits nothing, so keep the timer running.
      start(onGaveUp: onGaveUp);
    });
  }

  /// Stop retrying and forget the attempts so far. Called on any header
  /// progress (the connection came back) and on dispose.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _attempts = 0;
    _generation++;
  }

  @visibleForTesting
  int get attempts => _attempts;
}
