import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/ui/components/segment/segmented_full.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReceiveNetworkSelection extends StatelessWidget {
  const ReceiveNetworkSelection({super.key, this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BBSegmentFull(
        items:
            wallet == null
                ? const {'Bitcoin', 'Lightning', 'Liquid'}
                : wallet!.isLiquid
                ? const {'Lightning', 'Liquid'}
                : const {'Bitcoin', 'Lightning'},
        onSelected: (c) {
          // Pop the current route if it's not one of the main receive routes
          // This is to prevent the user from going back to the previous screen
          // when they select a different network
          // and then pressing the back button.
          // TODO: this is a temporary fix, we should handle this better in the future
          // with proper stateful nested navigation.
          final location = GoRouter.of(context).state.matchedLocation;
          if (location != ReceiveRoute.receiveBitcoin.path &&
              location != ReceiveRoute.receiveLightning.path &&
              location != ReceiveRoute.receiveLiquid.path) {
            context.pop();
          }
          if (c == 'Bitcoin') {
            context.pushReplacementNamed(
              ReceiveRoute.receiveBitcoin.name,
              extra: wallet,
            );
          } else if (c == 'Lightning') {
            context.pushReplacementNamed(
              ReceiveRoute.receiveLightning.name,
              extra: wallet,
            );
          } else if (c == 'Liquid') {
            context.pushReplacementNamed(
              ReceiveRoute.receiveLiquid.name,
              extra: wallet,
            );
          }
        },
        initialValue:
            wallet == null
                ? 'Lightning'
                : wallet!.isLiquid
                ? 'Liquid'
                : 'Bitcoin',
      ),
    );
  }
}
