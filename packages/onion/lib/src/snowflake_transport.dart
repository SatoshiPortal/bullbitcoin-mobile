import 'dart:io';

import 'package:flutter/services.dart';

/// Process-wide Snowflake pluggable transport supplied by IPtProxy on mobile.
abstract final class SnowflakeTransport {
  static const MethodChannel _channel = MethodChannel(
    'com.bullbitcoin.onion/snowflake',
  );

  static Future<int>? _starting;
  static int? _port;

  /// Acquires this Flutter engine's lease and returns the loopback SOCKS port.
  static Future<int> start() {
    _ensureSupported();
    final port = _port;
    if (port != null) return Future.value(port);
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  /// Releases this Flutter engine's lease.
  static Future<void> stop() async {
    _ensureSupported();
    final starting = _starting;
    if (starting != null) {
      try {
        await starting;
      } on Object {
        return;
      }
    }
    if (_port == null) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } finally {
      _port = null;
    }
  }

  /// Version embedded in the resolved IPtProxy binary.
  static Future<String> version() async {
    _ensureSupported();
    final version = await _channel.invokeMethod<String>('version');
    if (version == null || version.isEmpty) {
      throw StateError('IPtProxy did not report its Snowflake version');
    }
    return version;
  }

  static Future<int> _start() async {
    final port = await _channel.invokeMethod<int>('start');
    if (port == null || port < 1 || port > 65535) {
      throw StateError('IPtProxy did not bind a valid Snowflake port');
    }
    _port = port;
    return port;
  }

  static void _ensureSupported() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Snowflake is supported on Android and iOS');
    }
  }
}
