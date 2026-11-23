import 'exchange_cubit.dart';
import 'exchange_state.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Listens to ExchangeCubit state changes and manages WebSocket connection lifecycle.
///
/// - Disconnects WebSocket when the account is cleared (userSummary becomes
///   null); [ExchangeCubit] opens it on every signed-in access state
/// - Reconnects WebSocket when the app returns from the background, as the OS
///   may have dropped the connection while it was hidden
///
/// For network changes (mainnet/testnet switch), call [ExchangeCubit.reconnectWebSocket]
/// from the settings screen or wherever the network change is triggered.
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
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExchangeCubit, ExchangeState>(
      listenWhen: (previous, current) =>
          previous.userSummary != null && current.userSummary == null,
      listener: (context, state) =>
          context.read<ExchangeCubit>().disconnectWebSocket(),
      child: widget.child,
    );
  }
}
