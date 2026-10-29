import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A short iOS assertion for draining already-polled safe batches before stop.
/// It never waits for an unavailable on-demand native boundary.
final class CbfBackgroundPersistence {
  final MethodChannel _channel;
  final TargetPlatform _platform;
  final _expired = StreamController<void>.broadcast(sync: true);
  bool _active = false;
  bool _disposed = false;
  Future<void> _operations = Future.value();

  CbfBackgroundPersistence({
    this._channel = const MethodChannel(
      'com.bullbitcoin.mobile/cbf_background',
    ),
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform {
    if (_platform == TargetPlatform.iOS) {
      _channel.setMethodCallHandler((call) async {
        if (!_disposed && call.method == 'expired') {
          _active = false;
          _expired.add(null);
        }
      });
    }
  }

  Stream<void> get expired => _expired.stream;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<bool> begin() => _serialize(() async {
    if (_disposed || _platform != TargetPlatform.iOS) return false;
    if (_active) return true;
    try {
      return _active = await _channel.invokeMethod<bool>('begin') == true;
    } on Exception {
      return false;
    }
  });

  Future<void> end() => _serialize(() async {
    if (!_active) return;
    _active = false;
    try {
      await _channel.invokeMethod<void>('end');
    } on Exception {
      /* Native expiration independently ends the assertion. */
    }
  });

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await end();
    if (_platform == TargetPlatform.iOS) _channel.setMethodCallHandler(null);
    await _expired.close();
  }
}
