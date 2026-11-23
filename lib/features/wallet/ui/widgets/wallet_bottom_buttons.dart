import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:receive/receive.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:receive/routes.dart';
import 'package:send/send.dart' show SendNavigation;
import 'package:bull_ui/bull_ui.dart'
    show BullReceiveSendButtons, BuildContext, StatelessWidget, Widget;
import 'package:sync/sync.dart' show WalletKey;

class WalletBottomButtons extends StatelessWidget {
  const WalletBottomButtons({super.key, this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    return BullReceiveSendButtons(
      receiveLabel: context.loc.walletButtonReceive,
      sendLabel: context.loc.walletButtonSend,
      onReceive: () {
        final selected = wallet;
        ReceiveNavigation.open<void>(
          context,
          wallet: selected == null
              ? null
              : ReceiveWallet(
                  id: selected.id,
                  network: selected.network.shared,
                  signsLocally: selected.signsLocally,
                  scriptType: selected.scriptType,
                ),
        );
      },
      onSend: wallet?.isWatchOnly == true
          ? null
          : () {
              final selected = wallet;
              SendNavigation.open(
                context,
                wallet: selected == null
                    ? null
                    : WalletKey(
                        id: selected.id,
                        network: selected.network.shared,
                      ),
              );
            },
    );
  }
}
