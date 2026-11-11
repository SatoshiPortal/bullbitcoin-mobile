import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen awake while enabled and the app is in the foreground.
class ScreenAwakeScope extends StatefulWidget {
  const ScreenAwakeScope({
    required this.enabled,
    required this.child,
    super.key,
  });

  final bool enabled;
  final Widget child;

  @override
  State<ScreenAwakeScope> createState() => _ScreenAwakeScopeState();
}

class _ScreenAwakeScopeState extends State<ScreenAwakeScope>
    with WidgetsBindingObserver {
  static int _activeScopes = 0;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void didUpdateWidget(ScreenAwakeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  void _sync() => _setActive(
    widget.enabled &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
  );

  void _setActive(bool active) {
    if (_active == active) return;
    _active = active;
    // Removing one screen must not release another screen's wake lock.
    _activeScopes += active ? 1 : -1;
    unawaited(_toggle(_activeScopes > 0));
  }

  static Future<void> _toggle(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on Exception catch (exception, stack) {
      log.warning(
        'Screen awake update failed',
        error: exception.runtimeType,
        trace: stack,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
