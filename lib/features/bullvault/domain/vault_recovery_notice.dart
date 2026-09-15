import 'dart:async';

/// A vault that was recovered and has not been announced on the home screen.
///
/// One flag for the life of the process. The home alert has to appear after a
/// wallet was actually persisted, exactly once, and a restart must not repeat
/// it — a durable record would say "recovered" forever, and a discovery that
/// imported nothing must say nothing at all.
final class VaultRecoveryNotice {
  final _recorded = StreamController<void>.broadcast();
  bool _pending = false;

  /// Called when a recovery really put a vault on this device.
  void record() {
    _pending = true;
    _recorded.add(null);
  }

  /// Fires on every [record], so a screen that has already asked hears about a
  /// recovery that lands afterwards.
  ///
  /// A recovery persists its wallets before it announces them, and the wallet
  /// list the home screen holds is rebuilt from exactly those writes, so
  /// asking when that list changes is asking once too early.
  Stream<void> get recordings => _recorded.stream;

  /// Whether there is an unannounced recovery, clearing it as it answers.
  bool take() {
    final pending = _pending;
    _pending = false;
    return pending;
  }
}
