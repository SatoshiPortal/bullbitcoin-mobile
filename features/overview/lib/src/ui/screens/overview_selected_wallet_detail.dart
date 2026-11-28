import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show LiquidNetwork;
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:sync/sync.dart' show WalletKey;

import '../../domain/overview_detail_controller.dart';
import '../widgets/overview_wallet_buttons.dart';
import 'overview_wallet_detail.dart';

typedef OverviewDetailSlot = Widget Function(
  BuildContext,
  OverviewDetailWallet,
);

/// Composes the selected catalogue wallet with its owners' presentation slots.
class OverviewSelectedWalletDetail extends StatelessWidget {
  const OverviewSelectedWalletDetail({
    super.key,
    required this.controller,
    required this.defaultBitcoinLabel,
    required this.defaultLiquidLabel,
    required this.unavailableMessage,
    required this.settings,
    required this.scopeWalletHistory,
    required this.refreshPrice,
    required this.refreshWalletHistory,
    required this.balanceCard,
    required this.consolidation,
    required this.coinsEntry,
    required this.liquidDisclosure,
    required this.history,
    required this.receiveLabel,
    required this.sendLabel,
    required this.onReceive,
    required this.onSend,
  });

  final OverviewDetailController controller;
  final String defaultBitcoinLabel;
  final String defaultLiquidLabel;
  final String unavailableMessage;
  final Widget settings;
  final Widget Function(String walletId, Widget child) scopeWalletHistory;
  final Future<void> Function(BuildContext) refreshPrice;
  final Future<void> Function(BuildContext) refreshWalletHistory;
  final OverviewDetailSlot balanceCard;
  final OverviewDetailSlot consolidation;
  final OverviewDetailSlot coinsEntry;
  final OverviewDetailSlot liquidDisclosure;
  final OverviewDetailSlot history;
  final String receiveLabel;
  final String sendLabel;
  final void Function(OverviewReceiveTarget target) onReceive;
  final void Function(WalletKey key) onSend;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<OverviewDetailWallet?>(
        valueListenable: controller,
        builder: (context, wallet, _) {
          final liquid = wallet?.key.network is LiquidNetwork;
          final name = wallet == null
              ? ''
              : wallet.isDefault
              ? (liquid ? defaultLiquidLabel : defaultBitcoinLabel)
              : wallet.label ?? wallet.origin;
          return OverviewWalletDetail(
            walletId: controller.walletId,
            walletName: name,
            settings: settings,
            isLoading: wallet == null,
            unavailableMessage: unavailableMessage,
            hasBalance: wallet?.balanceSat != null,
            isLiquid: liquid,
            scopeWalletHistory: scopeWalletHistory,
            refreshPrice: refreshPrice,
            refreshWalletHistory: refreshWalletHistory,
            balanceCard: (context) => wallet == null
                ? const SizedBox.shrink()
                : balanceCard(context, wallet),
            consolidation: (context) => wallet == null
                ? const SizedBox.shrink()
                : consolidation(context, wallet),
            coinsEntry: (context) => wallet == null
                ? const SizedBox.shrink()
                : coinsEntry(context, wallet),
            liquidDisclosure: (context) => wallet == null
                ? const SizedBox.shrink()
                : liquidDisclosure(context, wallet),
            history: (context) => wallet == null
                ? const SliverToBoxAdapter()
                : history(context, wallet),
            bottomActions: wallet == null
                ? const SizedBox.shrink()
                : OverviewWalletButtons.wallet(
                    target: (
                      key: wallet.key,
                      scriptType: wallet.scriptType,
                      signsLocally: wallet.signer == WalletSigner.local,
                    ),
                    watchOnly: wallet.signer == WalletSigner.none,
                    receiveLabel: receiveLabel,
                    sendLabel: sendLabel,
                    onReceive: (target) {
                      if (target != null) onReceive(target);
                    },
                    onSend: (key) {
                      if (key != null) onSend(key);
                    },
                    isCurrent: () => wallet.isCurrent,
                  ),
          );
        },
      );
}
