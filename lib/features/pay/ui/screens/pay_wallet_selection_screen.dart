import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
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
      appBar: AppBar(
        title: const Text('Select Wallet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<PayBloc>().add(
              const PayEvent.walletSelectionBackPressed(),
            );
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            FadingLinearProgress(
              height: 3,
              trigger: isCreatingPayOrder,
              backgroundColor: context.colour.onPrimary,
              foregroundColor: context.colour.primary,
            ),
            Expanded(
              child: ScrollableColumn(
                children: [
                  const Gap(24.0),
                  Text(
                    'Which wallet do you want to pay from?',
                    style: context.font.labelMedium?.copyWith(
                      color: Colors.black,
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
                    tileColor: context.colour.onPrimary,
                    shape: const Border(),
                    title: const Text('External wallet'),
                    subtitle: const Text('Pay from another Bitcoin wallet'),
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
          'You are trying to pay above the maximum amount that can be paid with this wallet.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        BelowMinAmountPayError _ => Text(
          'You are trying to pay below the minimum amount that can be paid with this wallet.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        InsufficientBalancePayError _ => Text(
          'Insufficient balance in the selected wallet to complete this pay order.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        UnauthenticatedPayError _ => Text(
          'You are not authenticated. Please log in to continue.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        OrderNotFoundPayError _ => Text(
          'The pay order was not found. Please try again.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        OrderAlreadyConfirmedPayError _ => Text(
          'This pay order has already been confirmed.',
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        UnexpectedPayError _ => Text(
          payError.message,
          style: context.font.bodyMedium?.copyWith(color: context.colour.error),
          textAlign: TextAlign.center,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
