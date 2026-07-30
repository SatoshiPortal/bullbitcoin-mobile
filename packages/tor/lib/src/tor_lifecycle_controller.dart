import 'dart:async';

import 'package:flutter/widgets.dart';

import 'data/tor_logger.dart';
import 'domain/usecases/set_tor_dormant_usecase.dart';

final class TorLifecycleController {
  final SetTorDormantUsecase _setTorDormantUsecase;
  final TorLogger _log;
  AppLifecycleListener? _listener;
  Future<void> _dormancyTail = Future<void>.value();
  bool? _dormant;

  TorLifecycleController(this._setTorDormantUsecase, this._log);

  void start() {
    if (_listener != null) return;
    _listener = AppLifecycleListener(onStateChange: _onStateChanged);
    final currentState = WidgetsBinding.instance.lifecycleState;
    if (currentState != null) _onStateChanged(currentState);
  }

  void dispose() {
    _listener?.dispose();
    _listener = null;
  }

  void _onStateChanged(AppLifecycleState state) {
    final dormant = state != AppLifecycleState.resumed;
    if (_dormant == dormant) return;
    _dormant = dormant;
    _dormancyTail = _dormancyTail.then((_) => _updateDormancy(dormant));
  }

  Future<void> _updateDormancy(bool dormant) async {
    try {
      await _setTorDormantUsecase.execute(dormant);
    } catch (error) {
      _log.warning('Failed to update embedded Tor dormancy: $error');
    }
  }
}
