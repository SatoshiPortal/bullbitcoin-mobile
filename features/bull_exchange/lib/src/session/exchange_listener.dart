import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Runs [onShow] when the app returns from the background: the OS may have
/// dropped the notification socket while it was hidden. The socket itself
/// opens and closes with the signed-in access state.
class ExchangeListener extends StatefulWidget {
  const ExchangeListener({
    super.key,
    required this.onShow,
    required this.child,
  });
  final Future<void> Function() onShow;
  final Widget child;

  @override
  State<ExchangeListener> createState() => _ExchangeListenerState();
}

class _ExchangeListenerState extends State<ExchangeListener> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onShow: () => unawaited(widget.onShow()),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
