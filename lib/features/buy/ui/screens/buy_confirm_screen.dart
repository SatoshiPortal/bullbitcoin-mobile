import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/components/timers/countdown.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class BuyConfirmScreen extends StatelessWidget {
  const BuyConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final buyOrder = context.select((BuyBloc bloc) => bloc.state.buyOrder!);
    final formattedPayInAmount = FormatAmount.fiat(
      buyOrder.payinAmount,
      buyOrder.payinCurrency.code,
    );
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit,
    );
    final payoutAmountBtc = buyOrder.payoutAmount;
    final payoutAmountSat = ConvertAmount.btcToSats(
      payoutAmountBtc,
    ); // Convert sats to BTC
    final formattedPayOutAmount =
        bitcoinUnit == BitcoinUnit.sats
            ? FormatAmount.sats(payoutAmountSat)
            : FormatAmount.btc(buyOrder.payoutAmount);
    final formattedExchangeRate = FormatAmount.fiat(
      buyOrder.exchangeRateAmount,
      buyOrder.exchangeRateCurrency,
    );
    const externalBitcoinWalletLabel = 'External Bitcoin wallet';
    const secureBitcoinWalletLabel = 'Secure Bitcoin Wallet';
    const instantPaymentWalletLabel = 'Instant payment wallet';
    final selectedWallet = context.select(
      (BuyBloc bloc) => bloc.state.selectedWallet,
    );
    final payoutMethod =
        selectedWallet == null
            ? externalBitcoinWalletLabel
            : selectedWallet.label ??
                (selectedWallet.isLiquid
                    ? instantPaymentWalletLabel
                    : secureBitcoinWalletLabel);

    final isConfirmingOrder = context.select(
      (BuyBloc bloc) => bloc.state.isConfirmingOrder,
    );
    final isRefreshingOrder = context.select(
      (BuyBloc bloc) => bloc.state.isRefreshingOrder,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Buy Bitcoin')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: context.colour.secondaryFixedDim,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(Assets.icons.btc.path),
                  ),
                ),
                const Gap(13),
                Center(
                  child: BBText(
                    formattedPayInAmount,
                    style: context.font.displaySmall,
                    color: context.colour.outlineVariant,
                  ),
                ),
                const Gap(32),
                _buildDetailRow(context, 'You pay', formattedPayInAmount),
                // _divider(context),
                _buildDetailRow(context, 'You receive', formattedPayOutAmount),
                // _divider(context),
                _buildDetailRow(
                  context,
                  'Bitcoin Price',
                  formattedExchangeRate,
                ),
                // _divider(context),
                _buildDetailRow(context, 'Payout method', payoutMethod),

                const Gap(32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isConfirmingOrder || isRefreshingOrder)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Awaiting confirmation ',
                      style: context.font.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: context.colour.outline,
                      ),
                    ),
                    const Gap(4),
                    Countdown(
                      until: buyOrder.confirmationDeadline,
                      onTimeout: () {
                        debugPrint('Confirmation deadline reached');
                        context.read<BuyBloc>().add(
                          const BuyEvent.refreshOrder(),
                        );
                      },
                    ),
                  ],
                ),
              const Gap(16),
              BBButton.big(
                label: 'Confirm purchase',
                disabled: isConfirmingOrder || isRefreshingOrder,
                onPressed: () {
                  context.read<BuyBloc>().add(const BuyEvent.confirmOrder());
                },
                bgColor: context.colour.secondary,
                textColor: context.colour.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            label,
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.surfaceContainer,
            ),
          ),
          const Spacer(),
          Expanded(
            child: BBText(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              style: context.font.bodyMedium?.copyWith(
                color: isError ? context.colour.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
