import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Listens to ExchangeCubit state changes and manages WebSocket connection lifecycle.
///
/// - Connects WebSocket when user logs in (userSummary becomes non-null)
/// - Disconnects WebSocket when user logs out (userSummary becomes null)
///
/// For network changes (mainnet/testnet switch), call [ExchangeCubit.reconnectWebSocket]
/// from the settings screen or wherever the network change is triggered.
class ExchangeListener extends StatelessWidget {
  const ExchangeListener({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExchangeCubit, ExchangeState>(
      listenWhen: (previous, current) =>
          previous.userSummary != current.userSummary,
      listener: (context, state) {
        final exchangeCubit = context.read<ExchangeCubit>();

        if (state.userSummary != null) {
          // User logged in - connect WebSocket
          exchangeCubit.connectWebSocket();
        } else {
          // User logged out - disconnect WebSocket
          exchangeCubit.disconnectWebSocket();
        }
      },
      child: child,
    );
  }
}
