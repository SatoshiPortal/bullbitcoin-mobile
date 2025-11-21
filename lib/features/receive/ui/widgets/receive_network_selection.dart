import 'package:bb_mobile/core/utils/build_context_x.dart';
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
    final bitcoin = context.loc.receiveBitcoin;
    final lightning = context.loc.receiveLightning;
    final liquid = context.loc.receiveLiquid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BBSegmentFull(
        items:
            wallet == null
                ? {bitcoin, lightning, liquid}
                : wallet!.isLiquid
                ? !wallet!.signsLocally
                    ? {liquid}
                    : {lightning, liquid}
                : !wallet!.signsLocally
                ? {bitcoin}
                : {bitcoin, lightning},
        onSelected: (c) {
          if (c == bitcoin) {
            context.goNamed(ReceiveRoute.receiveBitcoin.name, extra: wallet);
          } else if (c == lightning) {
            context.goNamed(ReceiveRoute.receiveLightning.name, extra: wallet);
          } else if (c == liquid) {
            context.goNamed(ReceiveRoute.receiveLiquid.name, extra: wallet);
          }
        },
        initialValue:
            wallet == null
                ? bitcoin
                : wallet!.isLiquid
                ? liquid
                : bitcoin,
      ),
    );
  }
}
