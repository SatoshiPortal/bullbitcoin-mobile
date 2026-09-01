import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/receive_send_buttons.dart';
import 'package:bb_mobile/features/receive/domain/enums/receive_network_type.dart';
import 'package:bb_mobile/features/receive/domain/extensions/wallet_receive_extensions.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WalletBottomButtons extends StatelessWidget {
  const WalletBottomButtons({super.key, this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    return ReceiveSendButtons(
      receiveLabel: context.loc.walletButtonReceive,
      sendLabel: context.loc.walletButtonSend,
      onReceive: () {
        final type =
            wallet?.defaultReceiveNetwork ?? ReceiveNetworkType.bitcoin;
        final routeName = switch (type) {
          ReceiveNetworkType.bitcoin => ReceiveRoute.receiveBitcoin.name,
          ReceiveNetworkType.lightning => ReceiveRoute.receiveLightning.name,
          ReceiveNetworkType.liquid => ReceiveRoute.receiveLiquid.name,
        };
        context.pushNamed(routeName, extra: wallet);
      },
      onSend: () => context.pushNamed(SendRoute.send.name, extra: wallet),
      sendDisabled: wallet?.isWatchOnly ?? false,
    );
  }
}
