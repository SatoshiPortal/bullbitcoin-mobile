import 'exchange_cubit.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reconnects the notification socket when the app returns from the
/// background, as the OS may have dropped the connection while it was hidden.
/// The socket itself opens and closes with the signed-in access state.
class ExchangeListener extends StatefulWidget {
  const ExchangeListener({super.key, required this.child});
  final Widget child;

  @override
  State<ExchangeListener> createState() => _ExchangeListenerState();
}

class _ExchangeListenerState extends State<ExchangeListener> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onShow: _onShow);
  }

  void _onShow() {
    final exchangeCubit = context.read<ExchangeCubit>();
    if (exchangeCubit.state.userSummary != null) {
      exchangeCubit.reconnectWebSocket();
      // The reconnect covers pushes from now on; this covers whatever was
      // pushed while the app was hidden and the socket was down.
      exchangeCubit.fetchUserSummary();
      exchangeCubit.refreshUnreadSupportMessages();
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
