import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/receive/domain/enums/receive_network_type.dart';
import 'package:bb_mobile/features/receive/domain/extensions/wallet_receive_extensions.dart';
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
            label: context.loc.walletButtonReceive,
            iconFirst: true,
            onPressed: () {
              final type = wallet.defaultReceiveNetwork;
              final routeName = switch (type) {
                ReceiveNetworkType.bitcoin => ReceiveRoute.receiveBitcoin.name,
                ReceiveNetworkType.lightning =>
                  ReceiveRoute.receiveLightning.name,
                ReceiveNetworkType.liquid => ReceiveRoute.receiveLiquid.name,
              };

              if (wallet == null) {
                context.pushNamed(routeName);
              } else {
                context.pushNamed(routeName, extra: wallet);
              }
            },
            bgColor: context.appColors.secondaryFixed,
            textColor: context.appColors.onSecondaryFixed,
            outlined: true,
            borderColor: context.appColors.onSecondaryFixed,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBButton.big(
            iconData: Icons.crop_free,
            label: context.loc.walletButtonSend,
            iconFirst: true,
            onPressed: () {
              context.pushNamed(SendRoute.send.name, extra: wallet);
            },
            bgColor: context.appColors.secondaryFixed,
            textColor: context.appColors.onSecondaryFixed,
            outlined: true,
            borderColor: context.appColors.onSecondaryFixed,
            disabled: wallet?.isWatchOnly ?? false,
          ),
        ),
      ],
    );
  }
}
