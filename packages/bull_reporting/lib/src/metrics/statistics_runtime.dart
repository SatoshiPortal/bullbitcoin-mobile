import 'dart:async';

import 'daily_active.dart';
import 'statistics_network.dart';
import 'statistics_transport.dart';

/// Coordinates the independent consent, release and active-network gates.
final class StatisticsRuntime {
  final StatisticsNetwork _network;
  final StatisticsTransport _transport;
  final bool _releaseMode;
  late final DailyActiveInstallations _daily;
  late final StreamSubscription<bool> _networkChanges;
  bool _consented = false;
  bool _foreground = false;
  bool _allowed = false;
  bool _disposed = false;
  int _revision = 0;

  StatisticsRuntime(
    this._network,
    this._transport,
    ActiveDayStore store,
    this._releaseMode, {
    DateTime Function()? clock,
  }) {
    _daily = DailyActiveInstallations(
      store,
      (instant) => unawaited(_emit(instant)),
      clock: clock,
    );
    _networkChanges = _network.changes.listen(
      (changing) => _networkChanged(changing),
      onError: (Object _, StackTrace _) => _invalidate(),
      onDone: _invalidate,
    );
  }

  void setConsent(bool enabled) {
    _consented = enabled;
    _invalidate();
    if (enabled) unawaited(_refresh());
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _daily.setForeground(foreground);
  }

  void _networkChanged(bool changing) {
    _invalidate();
    if (!changing) unawaited(_refresh());
  }

  void _invalidate() {
    _revision++;
    _allowed = false;
    _daily.setConsent(false);
    _transport.updateConsent(false);
  }

  Future<bool> _check(int revision) async {
    if (_disposed || !_releaseMode || !_consented || revision != _revision) {
      return false;
    }
    try {
      final mainnet = await _network.isMainnet();
      return mainnet &&
          !_disposed &&
          _releaseMode &&
          _consented &&
          revision == _revision;
    } on Exception {
      return false;
    }
  }

  Future<void> _refresh() async {
    final revision = _revision;
    if (!await _check(revision)) return;
    _allowed = true;
    _transport.updateConsent(true);
    _daily.setConsent(true);
    _daily.setForeground(_foreground);
  }

  Future<void> _emit(DateTime instant) async {
    final revision = _revision;
    if (!_allowed || !await _check(revision)) return;
    _transport.installationActive(instant);
  }

  /// Revalidates immediately before a network request is made.
  Future<bool> canSend() async {
    final revision = _revision;
    return _allowed && await _check(revision);
  }

  Future<void> get idle => _daily.idle;

  void dispose() {
    _disposed = true;
    _invalidate();
    unawaited(_networkChanges.cancel());
  }
}
