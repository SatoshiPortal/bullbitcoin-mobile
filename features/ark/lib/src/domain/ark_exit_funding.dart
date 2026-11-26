import 'dart:async';

import 'package:primitives/primitives.dart';

/// What started emergency exits wait for, while the app runs: how much the
/// Secure Bitcoin wallet must receive before they can pay their next fees,
/// and when it last sent fees to the reserve.
final class ArkExitFunding {
  final _changes = StreamController<void>.broadcast();
  Sats? _needed;
  DateTime? _sentAt;

  /// Missing from Secure Bitcoin for the exits to continue; null when
  /// nothing is missing.
  Sats? get needed => _needed;

  /// Fires when [needed] changes.
  Stream<void> get changes => _changes.stream;

  /// Whether fees were sent to the reserve less than [window] before [now].
  bool sentWithin(Duration window, DateTime now) {
    final sent = _sentAt;
    return sent != null && now.difference(sent) < window;
  }

  void sent(DateTime at) => _sentAt = at;

  void waitFor(Sats? amount) {
    if (amount == _needed) return;
    _needed = amount;
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> close() => _changes.close();
}
