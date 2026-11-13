import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Owns a short-lived clipboard value without clearing a later foreign copy.
final class SensitiveClipboard {
  final Duration lifetime;
  _PendingClear? _pending;
  bool _disposed = false;

  SensitiveClipboard({this.lifetime = const Duration(seconds: 30)});

  Future<bool> copy(String value) async {
    if (_disposed) return false;
    try {
      await Clipboard.setData(ClipboardData(text: value));
    } on PlatformException {
      return false;
    }
    _pending?.cancel();
    final pending = _PendingClear(value, lifetime);
    _pending = pending;
    if (_disposed) await pending.run();
    return !_disposed;
  }

  void dispose() {
    _disposed = true;
    final pending = _pending;
    if (pending != null) unawaited(pending.run());
  }
}

final class _PendingClear {
  String? _value;
  Timer? _timer;
  AppLifecycleListener? _listener;

  _PendingClear(this._value, Duration lifetime) {
    _timer = Timer(lifetime, () => unawaited(run()));
  }

  Future<void> run() async {
    final value = _value;
    if (value == null) return;
    _timer?.cancel();
    _timer = null;
    final ClipboardData? current;
    try {
      current = await Clipboard.getData(Clipboard.kTextPlain);
    } on PlatformException {
      _defer();
      return;
    }
    if (_value == null) return;
    if (current == null) {
      _defer();
      return;
    }
    if (current.text != value) {
      cancel();
      return;
    }
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
      cancel();
    } on PlatformException {
      _defer();
    }
  }

  void _defer() {
    _listener ??= AppLifecycleListener(onResume: () => unawaited(run()));
  }

  void cancel() {
    _value = null;
    _timer?.cancel();
    _timer = null;
    _listener?.dispose();
    _listener = null;
  }
}
