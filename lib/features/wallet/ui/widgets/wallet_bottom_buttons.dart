import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletBottomButtons extends StatelessWidget {
  const WalletBottomButtons({super.key, this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BBButton.big(
            iconData: Icons.arrow_downward,
            label: 'Receive',
            iconFirst: true,
            onPressed: () {
              // Lightning is the default receive method if no specific wallet is selected
              if (wallet == null) {
                context.pushNamed(ReceiveRoute.receiveLightning.name);
              } else {
                context.pushNamed(
                  wallet!.isLiquid
                      ? ReceiveRoute.receiveLiquid.name
                      : ReceiveRoute.receiveBitcoin.name,
                  extra: wallet,
                );
              }
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBButton.big(
            iconData: Icons.crop_free,
            label: 'Send',
            iconFirst: true,
            onPressed: () {
              context.pushNamed(SendRoute.send.name, extra: wallet);
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onPrimary,
            disabled: wallet?.isWatchOnly ?? false,
          ),
        ),
      ],
    );
  }
}
