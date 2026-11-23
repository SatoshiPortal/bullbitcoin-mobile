import 'dart:async';

import 'package:clock/clock.dart';

/// Decides *when* an order's quote must be refreshed, never *what* to do.
///
/// An exchange order carries a price lock that lapses at its confirmation
/// deadline; a payin sent after it is not credited. The owner (a bloc) keeps
/// the order and the refresh use case; this scheduler only fires [onDue] at
/// the exact instant the lock lapses, then at a bounded pace while the quotes
/// that come back are already lapsed or the refreshes fail. The owner reports
/// each outcome through [track] and [refreshFailed]; at most one timer is live
/// at any time, so [onDue] never overlaps itself.
///
/// It sits comfortably above a response cache: a cached answer still within
/// its TTL hands back the same lapsed deadline, which [track] treats as a retry
/// and waits [retryDelay] rather than asking again at once. Keep that delay
/// above any such TTL so a retry actually reaches the exchange.
///
/// Time is read through `package:clock`, so `fakeAsync` drives it in tests.
final class OrderDeadlineScheduler {
  /// Asked to refresh the quote: the lock lapsed, or a retry is due.
  final void Function() onDue;

  /// The retries are exhausted; the owner decides what the user sees.
  final void Function()? onGiveUp;

  /// Pause between retries after a lapsed quote or a failed refresh.
  final Duration retryDelay;

  /// Retries allowed per lapsed lock before [onGiveUp]. The bound is per lock,
  /// not per order: a fresh lock resets it, and so does giving up, so a later
  /// [track] of a lapsed lock (the user retrying) opens a new budget.
  final int maxRetries;

  Timer? _timer;
  int _retries = 0;
  bool _isDisposed = false;

  OrderDeadlineScheduler({
    required this.onDue,
    this.onGiveUp,
    this.retryDelay = const Duration(seconds: 5),
    this.maxRetries = 6,
  });

  /// Whether a refresh is scheduled.
  bool get isPending => _timer?.isActive ?? false;

  /// A quote arrived or the order changed. A deadline still ahead is a fresh
  /// lock: arm at that instant and forget past retries. A deadline already
  /// behind is a lapsed quote: retry after [retryDelay]. No deadline means
  /// nothing to watch.
  void track(DateTime? deadline) {
    if (_isDisposed) return;
    _clearTimer();
    if (deadline == null) {
      _retries = 0;
      return;
    }
    final remaining = deadline.difference(clock.now());
    if (remaining > Duration.zero) {
      _retries = 0;
      _timer = Timer(remaining, _fire);
      return;
    }
    _retry();
  }

  /// The refresh request itself failed: retry after [retryDelay].
  void refreshFailed() {
    if (_isDisposed) return;
    _clearTimer();
    _retry();
  }

  /// The order is gone or must not be refreshed any more.
  void cancel() {
    _clearTimer();
    _retries = 0;
  }

  /// Final: a refresh still in flight when the owner closes may report back
  /// afterwards, and must not arm a timer that would fire into a closed owner.
  void dispose() {
    _isDisposed = true;
    cancel();
  }

  void _retry() {
    if (_retries >= maxRetries) {
      _retries = 0;
      onGiveUp?.call();
      return;
    }
    _retries++;
    _timer = Timer(retryDelay, _fire);
  }

  void _fire() {
    _timer = null;
    onDue();
  }

  void _clearTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
