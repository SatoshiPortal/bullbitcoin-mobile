import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
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
              backgroundColor: context.colorScheme.onPrimary,
              foregroundColor: context.colorScheme.primary,
            ),
            Expanded(
              child: ScrollableColumn(
                children: [
                  const Gap(24.0),
                  Text(
                    context.loc.sellWhichWalletQuestion,
                    style: context.font.labelMedium?.copyWith(
                      color: Colors.black,
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
                    tileColor: context.colorScheme.onPrimary,
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

    return Center(
      child: switch (sellError) {
        AboveMaxAmountSellError _ => Text(
          context.loc.sellAboveMaxAmountError,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        BelowMinAmountSellError _ => Text(
          context.loc.sellBelowMinAmountError,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        InsufficientBalanceSellError _ => Text(
          context.loc.sellInsufficientBalanceError,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        UnauthenticatedSellError _ => Text(
          context.loc.sellUnauthenticatedError,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        OrderNotFoundSellError _ => Text(
          context.loc.sellOrderNotFoundError,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        OrderAlreadyConfirmedSellError _ => Text(
          context.loc.sellOrderAlreadyConfirmedError,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        UnexpectedSellError _ => Text(
          sellError.message,
          style: context.font.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
