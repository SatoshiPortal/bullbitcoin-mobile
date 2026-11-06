import 'package:flutter/widgets.dart';

/// Tracks visibility without turning transient focus loss into backgrounding.
class ForegroundLifecycle extends WidgetsBindingObserver {
  final WidgetsBinding _binding;
  late bool _isForeground;

  ForegroundLifecycle({WidgetsBinding? binding})
    : _binding = binding ?? WidgetsBinding.instance {
    final state = _binding.lifecycleState;
    _isForeground = state == null || state == AppLifecycleState.resumed;
    _binding.addObserver(this);
  }

  bool get isForeground => _isForeground;

  static bool nextState(
    AppLifecycleState state, {
    required bool wasForeground,
  }) => switch (state) {
    AppLifecycleState.resumed => true,
    AppLifecycleState.inactive => wasForeground,
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
  };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = nextState(state, wasForeground: _isForeground);
  }

  void dispose() => _binding.removeObserver(this);
}
