import 'package:bull_ui/bull_ui.dart'
    show BuildContext, BullAmount, BullHomeNotice, StatelessWidget, Widget;
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:swaps/swaps.dart';
import 'package:transactions/routes.dart';

import '../swap_l10n.dart';

/// A swap still in progress, as a Home notice. It opens the swap's
/// transaction details.
class HomeSwapNotice extends StatelessWidget {
  final Swap swap;

  const HomeSwapNotice({super.key, required this.swap});

  @override
  Widget build(BuildContext context) {
    final copy = context.swapCopyForLocale;
    return BullHomeNotice(
      icon: switch (swap) {
        LnReceiveSwap() => Icons.arrow_downward,
        LnSendSwap() => Icons.arrow_upward,
        ChainSwap() => Icons.swap_vert_rounded,
      },
      headline: BullAmount.signedSats(swap.amountSat, interactive: false),
      status: copy.swapHomeInProgress,
      detail: switch (swap.type) {
        SwapType.bitcoinToLiquid => copy.swapHomeBitcoinToLiquid,
        SwapType.liquidToBitcoin => copy.swapHomeLiquidToBitcoin,
        SwapType.lightningToLiquid => copy.swapHomeLightningToLiquid,
        SwapType.lightningToBitcoin => copy.swapHomeLightningToBitcoin,
        SwapType.liquidToLightning => copy.swapHomeLiquidToLightning,
        SwapType.bitcoinToLightning => copy.swapHomeBitcoinToLightning,
      },
      onTap: () => TransactionsNavigation.openDetails(
        context,
        TransactionDetailsTarget.swap(swap.id, walletId: swap.walletId),
        view: TransactionDetailsView.details,
      ),
    );
  }
}
