import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullScrollableColumn, BullTypographyX, Gap;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show LiquidNetwork;

/// Where a sell or pay payin comes from: one of the app's wallets (the
/// host's wallet cards) or another wallet on a rail that can be paid from
/// outside.
class PayinSourcePage extends StatelessWidget {
  const PayinSourcePage({
    super.key,
    required this.title,
    required this.ui,
    required this.onPicked,
    required this.onBack,
  });

  final String title;
  final ExchangePayinUi ui;
  final void Function(PayinSource source) onPicked;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(onPressed: onBack),
      ),
      body: SafeArea(
        child: BullScrollableColumn(
          padding: const EdgeInsets.all(16),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.loc.sellWhichWalletQuestion,
              style: context.bullType.subtitle,
            ),
            const Gap(16),
            ui.walletCards(
              context,
              (wallet) => onPicked(
                PayinFromAppWallet(
                  wallet.key.id,
                  wallet.key.network is LiquidNetwork
                      ? BtcNetwork.liquid
                      : BtcNetwork.bitcoin,
                  label: wallet.label,
                  isDefault: wallet.isDefault,
                ),
              ),
            ),
            const Gap(24),
            Text(
              context.loc.sellFromAnotherWallet,
              style: context.bullType.subtitle,
            ),
            const Gap(8),
            for (final rail in BitcoinRails.all)
              if (rail.canBeExternalPayin)
                ListTile(
                  title: Text(_railName(context, rail.network)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onPicked(PayinFromExternal(rail.network)),
                ),
          ],
        ),
      ),
    );
  }
}

String _railName(BuildContext context, BtcNetwork network) => switch (network) {
  BtcNetwork.bitcoin => context.loc.sellBitcoinOnChain,
  BtcNetwork.liquid => context.loc.sellLiquidNetwork,
  BtcNetwork.lightning => context.loc.sellLightningNetwork,
};
