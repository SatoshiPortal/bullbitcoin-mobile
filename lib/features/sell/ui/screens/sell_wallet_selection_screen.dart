import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core_deprecated/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SellWalletSelectionScreen extends StatelessWidget {
  const SellWalletSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Update BitcoinPriceBloc currency to match sell flow currency
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currency = context.read<SellBloc>().state.fiatCurrency;
      context.read<BitcoinPriceBloc>().add(
        BitcoinPriceCurrencyChanged(currencyCode: currency.code),
      );
    });

    final isCreatingSellOrder = context.select(
      (SellBloc bloc) =>
          bloc.state is SellWalletSelectionState &&
          (bloc.state as SellWalletSelectionState).isCreatingSellOrder,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.sellSelectWallet)),
      body: SafeArea(
        child: Column(
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: isCreatingSellOrder,
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            Expanded(
              child: ScrollableColumn(
                children: [
                  const Gap(24.0),
                  Text(
                    context.loc.sellWhichWalletQuestion,
                    style: context.font.labelMedium?.copyWith(
                      color: context.appColors.text,
                    ),
                  ),
                  const Gap(24.0),
                  WalletCards(
                    padding: EdgeInsets.zero,
                    onTap:
                        isCreatingSellOrder
                            ? null
                            : (wallet) => context.read<SellBloc>().add(
                              SellEvent.walletSelected(wallet: wallet),
                            ),
                    localSignersOnly: true,
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onPrimary,
                    shape: const Border(),
                    title: Text(context.loc.sellExternalWallet),
                    subtitle: Text(context.loc.sellFromAnotherWallet),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        isCreatingSellOrder
                            ? null
                            : () => context.pushNamed(
                              SellRoute.sellExternalWalletNetworkSelection.name,
                            ),
                  ),
                  const Gap(24.0),
                  const _SellError(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellError extends StatelessWidget {
  const _SellError();

  @override
  Widget build(BuildContext context) {
    final sellError = context.select(
      (SellBloc bloc) =>
          bloc.state is SellWalletSelectionState
              ? (bloc.state as SellWalletSelectionState).error
              : null,
    );

    if (sellError == null) return const SizedBox.shrink();

    return Center(
      child: Text(
        sellError.toTranslated(context),
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
