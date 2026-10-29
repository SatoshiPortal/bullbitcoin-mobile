import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

abstract interface class CbfForegroundService {
  bool get isActive;
  Stream<void> get protectionLost;
  Future<bool> start({required String title, required String body});
  Future<bool> renew();
  Future<void> stop();
  Future<void> dispose();
}

/// Platform protection for the existing owner isolate; no timer or node ownership.
final class AndroidCbfForegroundService implements CbfForegroundService {
  final NotificationPermissionsFacade _permissions;
  final MethodChannel _channel;
  final TargetPlatform _platform;
  final _lost = StreamController<void>.broadcast(sync: true);
  String? _owner;
  String? _startingOwner;
  int _generation = 0;
  bool _disposed = false;
  bool _permissionRequested = false;

  AndroidCbfForegroundService({
    required this._permissions,
    this._channel = const MethodChannel(
      'com.bullbitcoin.mobile/cbf_foreground',
    ),
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform {
    if (_platform == TargetPlatform.android) {
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'lost') return;
        final arguments = call.arguments;
        if (arguments is Map &&
            arguments['owner'] != null &&
            (arguments['owner'] == _owner ||
                arguments['owner'] == _startingOwner)) {
          _owner = null;
          _startingOwner = null;
          _generation++;
          if (!_disposed) _lost.add(null);
        }
      });
    }
  }

  @override
  bool get isActive => _owner != null;

  @override
  Stream<void> get protectionLost => _lost.stream;

  @override
  Future<bool> start({required String title, required String body}) async {
    if (_disposed || _platform != TargetPlatform.android) return false;
    if (_owner != null) return renew();
    final generation = ++_generation;
    try {
      var allowed = await _permissions.isEnabled();
      if (allowed case Ok(value: false) when !_permissionRequested) {
        _permissionRequested = true;
        allowed = await _permissions.request();
      }
      if (allowed is! Ok<bool, NotificationsFailure> ||
          !allowed.value ||
          generation != _generation ||
          _disposed) {
        return false;
      }
      final random = Random.secure();
      final owner = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _startingOwner = owner;
      final started = await _channel.invokeMethod<bool>('start', {
        'owner': owner,
        'title': title,
        'body': body,
      });
      if (generation != _generation || _disposed) {
        await _channel.invokeMethod<void>('stop', {'owner': owner});
        return false;
      }
      _startingOwner = null;
      if (started != true) return false;
      _owner = owner;
      return true;
    } on Exception {
      if (generation == _generation) await stop();
      return false;
    }
  }

  /// Call from the existing owner poll, at most once per second. This must not
  /// introduce an independently ticking timer that keeps a frozen engine alive.
  @override
  Future<bool> renew() async {
    final owner = _owner;
    if (_disposed || owner == null) return false;
    try {
      if (await _channel.invokeMethod<bool>('renew', {'owner': owner}) ==
          true) {
        return owner == _owner;
      }
    } on Exception {
      // Unsupported, denied and expired protection all use the resume fallback.
    }
    if (_owner == owner) {
      _owner = null;
      _generation++;
      if (!_disposed) _lost.add(null);
    }
    return false;
  }

  @override
  Future<void> stop() async {
    _generation++;
    final owner = _owner ?? _startingOwner;
    _owner = null;
    _startingOwner = null;
    if (owner == null) return;
    try {
      await _channel.invokeMethod<void>('stop', {'owner': owner});
    } on Exception {
      // Native heartbeat expiry independently removes stale protection.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    if (_platform == TargetPlatform.android) {
      _channel.setMethodCallHandler(null);
    }
    await _lost.close();
  }
}
