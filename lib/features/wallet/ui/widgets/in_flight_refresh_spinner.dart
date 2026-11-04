import 'package:flutter/material.dart';

/// Shows a [RefreshIndicator] spinner over a refresh the app already started.
///
/// `RefreshIndicatorState.show` runs the indicator's `onRefresh`, which for a
/// pull gesture starts a user sync; during [show] that call follows the
/// running refresh instead.
final class InFlightRefreshSpinner {
  bool _following = false;

  void show(RefreshIndicatorState? indicator) {
    if (indicator == null) return;
    _following = true;
    indicator.show().whenComplete(() => _following = false);
  }

  /// The indicator's `onRefresh`: [follow] while [show] runs, [userRefresh]
  /// for a pull gesture.
  Future<void> onRefresh({
    required Future<void> Function() userRefresh,
    required Future<void> Function() follow,
  }) {
    if (!_following) return userRefresh();
    _following = false;
    return follow();
  }
}
