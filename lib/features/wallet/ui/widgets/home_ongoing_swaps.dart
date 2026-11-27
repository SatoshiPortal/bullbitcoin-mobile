import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:swaps/swaps.dart';
import 'package:transactions/routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullAmount, BullCarousel, BullHomeNotice, BullSizes;

/// One notice per swap still in progress, swipeable when there are several.
/// A notice opens the swap's transaction details.
class HomeOngoingSwaps extends StatelessWidget {
  const HomeOngoingSwaps({super.key});

  @override
  Widget build(BuildContext context) {
    final swaps = context.select((WalletBloc bloc) => bloc.state.ongoingSwaps);
    if (swaps.isEmpty) return const SizedBox.shrink();
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
              status: context.loc.walletHomeSwapInProgress,
              detail: switch (swap.type) {
                SwapType.bitcoinToLiquid =>
                  context.loc.walletHomeSwapBitcoinToLiquid,
                SwapType.liquidToBitcoin =>
                  context.loc.walletHomeSwapLiquidToBitcoin,
                SwapType.lightningToLiquid =>
                  context.loc.walletHomeSwapLightningToLiquid,
                SwapType.lightningToBitcoin =>
                  context.loc.walletHomeSwapLightningToBitcoin,
                SwapType.liquidToLightning =>
                  context.loc.walletHomeSwapLiquidToLightning,
                SwapType.bitcoinToLightning =>
                  context.loc.walletHomeSwapBitcoinToLightning,
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
