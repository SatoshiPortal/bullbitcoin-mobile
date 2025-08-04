import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
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
                ? !wallet!.signsLocally
                    ? const {'Liquid'}
                    : const {'Lightning', 'Liquid'}
                : !wallet!.signsLocally
                ? const {'Bitcoin'}
                : const {'Bitcoin', 'Lightning'},
        onSelected: (c) {
          if (c == 'Bitcoin') {
            context.goNamed(ReceiveRoute.receiveBitcoin.name, extra: wallet);
          } else if (c == 'Lightning') {
            context.goNamed(ReceiveRoute.receiveLightning.name, extra: wallet);
          } else if (c == 'Liquid') {
            context.goNamed(ReceiveRoute.receiveLiquid.name, extra: wallet);
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
