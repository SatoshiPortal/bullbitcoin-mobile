import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:receive/receive.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:overview/overview.dart'
    show OverviewReceiveTarget, OverviewWalletButtons;
import 'package:receive/routes.dart';
import 'package:send/send.dart' show SendNavigation;
import 'package:bull_ui/bull_ui.dart'
    show BuildContext, SizedBox, StatelessWidget, Widget;
import 'package:sync/sync.dart' show WalletKey;

class WalletBottomButtons extends StatelessWidget {
  const WalletBottomButtons({super.key}) : wallet = null, _detail = false;

  const WalletBottomButtons.detail({super.key, required this.wallet})
    : _detail = true;

  final Wallet? wallet;
  final bool _detail;

  @override
  Widget build(BuildContext context) {
    void openReceive(OverviewReceiveTarget? target) =>
        ReceiveNavigation.open<void>(
          context,
          wallet: target == null
              ? null
              : ReceiveWallet(
                  id: target.key.id,
                  network: target.key.network,
                  scriptType: target.scriptType,
                  signsLocally: target.signsLocally,
                ),
        );
    void openSend(WalletKey? key) => SendNavigation.open(context, wallet: key);
    final receiveLabel = context.loc.walletButtonReceive;
    final sendLabel = context.loc.walletButtonSend;
    if (!_detail) {
      return OverviewWalletButtons.home(
        receiveLabel: receiveLabel,
        sendLabel: sendLabel,
        onReceive: openReceive,
        onSend: openSend,
      );
    }
    final selected = wallet;
    if (selected == null) return const SizedBox.shrink();
    final bloc = context.watch<WalletBloc>();
    final generation = bloc.walletActionsGeneration;
    if (generation == null) return const SizedBox.shrink();

    final target = _receiveTarget(selected);
    return OverviewWalletButtons.wallet(
      target: target,
      watchOnly: selected.isWatchOnly,
      receiveLabel: receiveLabel,
      sendLabel: sendLabel,
      onReceive: openReceive,
      onSend: openSend,
      isCurrent: () =>
          bloc.walletActionsGeneration == generation &&
          bloc.state.wallets.any(
            (wallet) =>
                _receiveTarget(wallet) == target &&
                wallet.isWatchOnly == selected.isWatchOnly,
          ),
    );
  }

  static OverviewReceiveTarget _receiveTarget(Wallet wallet) => (
    key: WalletKey(id: wallet.id, network: wallet.network.shared),
    scriptType: wallet.scriptType,
    signsLocally: wallet.signsLocally,
  );
}
