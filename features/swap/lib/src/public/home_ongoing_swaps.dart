import 'package:bull_ui/bull_ui.dart'
    show
        BuildContext,
        BullAmount,
        BullCarousel,
        BullHomeNotice,
        BullSizes,
        EdgeInsets,
        Padding,
        SizedBox,
        StatelessWidget,
        ValueKey,
        Widget;
import 'package:material_ui/material_ui.dart' show Icons;
import 'package:swaps/swaps.dart';
import 'package:transactions/routes.dart';

import '../swap_l10n.dart';

/// One notice per swap, in the caller's order, swipeable when there are several.
/// A notice opens the swap's transaction details.
class HomeOngoingSwaps extends StatelessWidget {
  final List<Swap> swaps;

  const HomeOngoingSwaps({super.key, required this.swaps});

  @override
  Widget build(BuildContext context) {
    if (swaps.isEmpty) return const SizedBox.shrink();
    final copy = context.swapCopyForLocale;
    return Padding(
      padding: const EdgeInsets.only(
        left: 13,
        right: 13,
        top: BullSizes.homeCardGap,
      ),
      child: BullCarousel(
        children: [
          for (final swap in swaps)
            BullHomeNotice(
              key: ValueKey(swap.id),
              icon: switch (swap) {
                LnReceiveSwap() => Icons.arrow_downward,
                LnSendSwap() => Icons.arrow_upward,
                ChainSwap() => Icons.swap_vert_rounded,
              },
              headline: BullAmount.signedSats(
                swap.amountSat,
                interactive: false,
              ),
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
            ),
        ],
      ),
    );
  }
}
