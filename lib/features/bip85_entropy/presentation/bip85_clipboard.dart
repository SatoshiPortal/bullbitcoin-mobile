import 'dart:async';

import 'package:flutter/services.dart';

/// Owns the copy's lifetime independently of the screen displaying it.
abstract final class Bip85Clipboard {
  static int _generation = 0;
  static Timer? _timer;
  static Future<void> _operations = Future<void>.value();

  static Future<void> copy(String value) => _serialize(() async {
    await Clipboard.setData(ClipboardData(text: value));
    final generation = ++_generation;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 30), () {
      unawaited(
        _serialize(() async {
          try {
            final current = await Clipboard.getData(Clipboard.kTextPlain);
            if (generation == _generation && current?.text == value) {
              await Clipboard.setData(const ClipboardData(text: ''));
            }
          } on PlatformException {
            // Clipboard access may be unavailable while the app is backgrounded.
          }
        }),
      );
    });
  });

  static Future<void> _serialize(Future<void> Function() operation) async {
    final previous = _operations;
    final completed = Completer<void>();
    _operations = completed.future;
    await previous;
    try {
      await operation();
    } finally {
      completed.complete();
    }
  }
}
