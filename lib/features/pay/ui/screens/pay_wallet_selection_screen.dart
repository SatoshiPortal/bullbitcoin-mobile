import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class PayWalletSelectionScreen extends StatelessWidget {
  const PayWalletSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Update BitcoinPriceBloc currency to match pay flow currency
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currency = context.read<PayBloc>().state.currency;
      context.read<BitcoinPriceBloc>().add(
        BitcoinPriceCurrencyChanged(currencyCode: currency.code),
      );
    });
    final isCreatingPayOrder = context.select(
      (PayBloc bloc) =>
          bloc.state is PayWalletSelectionState &&
          (bloc.state as PayWalletSelectionState).isCreatingPayOrder,
    );

    final currency = context.select((PayBloc bloc) => bloc.state.currency);

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.paySelectWallet)),
      body: SafeArea(
        child: Column(
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: isCreatingPayOrder,
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            Expanded(
              child: ScrollableColumn(
                children: [
                  const Gap(24.0),
                  Text(
                    context.loc.payWhichWallet,
                    style: context.font.labelMedium?.copyWith(
                      color: context.appColors.text,
                    ),
                  ),
                  const Gap(24.0),
                  WalletCards(
                    padding: EdgeInsets.zero,
                    onTap:
                        isCreatingPayOrder
                            ? null
                            : (wallet) => context.read<PayBloc>().add(
                              PayEvent.walletSelected(wallet: wallet),
                            ),
                    localSignersOnly: true,
                    fiatCurrency: currency.code,
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onPrimary,
                    shape: const Border(),
                    title: Text(context.loc.payExternalWallet),
                    subtitle: Text(context.loc.payExternalWalletDescription),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        isCreatingPayOrder
                            ? null
                            : () => context.pushNamed(
                              PayRoute.payExternalWalletNetworkSelection.name,
                              extra: context.read<PayBloc>(),
                            ),
                  ),
                  const Gap(24.0),
                  const _PayError(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayError extends StatelessWidget {
  const _PayError();

  @override
  Widget build(BuildContext context) {
    final payError = context.select(
      (PayBloc bloc) =>
          bloc.state is PayWalletSelectionState
              ? (bloc.state as PayWalletSelectionState).error
              : null,
    );

    return Center(
      child: switch (payError) {
        AboveMaxAmountPayError _ => Text(
          context.loc.payAboveMaxAmount,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: TextAlign.center,
        ),
        BelowMinAmountPayError _ => Text(
          context.loc.payBelowMinAmount,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: TextAlign.center,
        ),
        InsufficientBalancePayError _ => Text(
          context.loc.payInsufficientBalance,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: TextAlign.center,
        ),
        UnauthenticatedPayError _ => Text(
          context.loc.payNotAuthenticated,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: TextAlign.center,
        ),
        OrderNotFoundPayError _ => Text(
          context.loc.payOrderNotFound,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: TextAlign.center,
        ),
        OrderAlreadyConfirmedPayError _ => Text(
          context.loc.payOrderAlreadyConfirmed,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: TextAlign.center,
        ),
        UnexpectedPayError _ => Text(
          payError.message,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: TextAlign.center,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
