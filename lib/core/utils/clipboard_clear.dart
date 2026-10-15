import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

/// Clears one copied secret from the clipboard, unless something else was
/// copied since. Android 10+ hides the clipboard from a backgrounded app, so an
/// unreadable clipboard is cleared on the next return to the foreground.
/// Comparing needs a read: if another app copied since, Android 12+ shows its
/// paste toast and iOS 16+ asks to allow pasting. Keyboard clipboard history
/// and clipboard sync keep their own copy; this only clears the primary clip.
final class ClipboardClear {
  final String _copied;
  Timer? _timer;
  AppLifecycleListener? _resumeListener;
  bool _finished = false;

  ClipboardClear(this._copied, Duration after) {
    _timer = Timer(after, () => unawaited(run()));
  }

  /// Clears now instead of waiting for the delay, e.g. when the screen closes;
  /// still leaves the clipboard alone if it no longer holds the copied value.
  Future<void> run({bool lastAttempt = false}) async {
    if (_finished) return;
    _timer?.cancel();
    _timer = null;
    final ClipboardData? current;
    try {
      current = await Clipboard.getData(Clipboard.kTextPlain);
    } on PlatformException {
      // Never clear what may not be ours.
      cancel();
      return;
    }
    if (_finished) return;
    if (current == null && !lastAttempt) {
      _resumeListener ??= AppLifecycleListener(
        onResume: () => unawaited(run(lastAttempt: true)),
      );
      return;
    }
    cancel();
    if (current?.text == _copied) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  void cancel() {
    _finished = true;
    _timer?.cancel();
    _timer = null;
    _resumeListener?.dispose();
    _resumeListener = null;
  }
}
