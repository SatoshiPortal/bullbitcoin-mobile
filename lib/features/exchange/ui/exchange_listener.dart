import 'package:bb_mobile/core/utils/foreground_lifecycle.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Listens to ExchangeCubit state changes and manages WebSocket connection lifecycle.
///
/// - Connects WebSocket when user logs in (userSummary becomes non-null)
/// - Disconnects WebSocket when user logs out (userSummary becomes null)
/// - Suspends the socket when the app becomes hidden, paused, or detached
/// - Reconnects and catches up account state only after returning to resumed
/// - Keeps the previous visibility during transient inactive states (dialogs,
///   biometric prompts), avoiding reconnect and account-refresh churn
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
  late bool _isForeground;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _isForeground = state == null || state == AppLifecycleState.resumed;
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChange,
    );
  }

  void _onLifecycleChange(AppLifecycleState state) {
    log.fine('Exchange notifications lifecycle: ${state.name}');
    final wasForeground = _isForeground;
    _isForeground = ForegroundLifecycle.nextState(
      state,
      wasForeground: wasForeground,
    );
    if (!_isForeground) {
      if (wasForeground) context.read<ExchangeCubit>().disconnectWebSocket();
      return;
    }
    if (wasForeground) return;

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
          previous.userSummary != current.userSummary,
      listener: (context, state) {
        final exchangeCubit = context.read<ExchangeCubit>();

        if (state.userSummary != null) {
          if (!_isForeground) return;
          // User logged in - connect WebSocket
          exchangeCubit.connectWebSocket();
        } else {
          // User logged out - disconnect WebSocket
          exchangeCubit.disconnectWebSocket();
        }
      },
      child: widget.child,
    );
  }
}
