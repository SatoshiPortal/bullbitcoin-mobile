import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_confirm_detail_row.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
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
      buyOrder.payinCurrency,
    );
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit,
    );
    final payoutAmountBtc = buyOrder.payoutAmount;
    final payoutAmountSat = ConvertAmount.btcToSats(
      payoutAmountBtc,
    ); // Convert sats to BTC
    final formattedPayOutAmount = bitcoinUnit == BitcoinUnit.sats
        ? FormatAmount.sats(payoutAmountSat)
        : FormatAmount.btc(buyOrder.payoutAmount);
    final formattedExchangeRate = FormatAmount.fiat(
      buyOrder.exchangeRateAmount!,
      buyOrder.exchangeRateCurrency!,
    );
    final externalBitcoinWalletLabel = context.loc.buyConfirmExternalWallet;
    final selectedWallet = context.select(
      (BuyBloc bloc) => bloc.state.selectedWallet,
    );
    final payoutMethod = selectedWallet == null
        ? externalBitcoinWalletLabel
        : selectedWallet.displayLabel(context);

    final isConfirmingOrder = context.select(
      (BuyBloc bloc) => bloc.state.isConfirmingOrder,
    );
    final isRefreshingOrder = context.select(
      (BuyBloc bloc) => bloc.state.isRefreshingOrder,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.buyConfirmTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: context.appColors.secondaryFixedDim,
                      shape: .circle,
                    ),
                    child: Image.asset(Assets.icons.btc.path),
                  ),
                ),
                const Gap(13),
                Center(
                  child: BBText(
                    formattedPayInAmount,
                    style: context.font.displaySmall,
                    color: context.appColors.outlineVariant,
                  ),
                ),
                const Gap(32),
                BuyConfirmDetailRow(
                  label: context.loc.buyConfirmYouPay,
                  value: formattedPayInAmount,
                ),
                BuyConfirmDetailRow(
                  label: context.loc.buyConfirmYouReceive,
                  value: formattedPayOutAmount,
                ),
                BuyConfirmDetailRow(
                  label: context.loc.buyConfirmBitcoinPrice,
                  value: formattedExchangeRate,
                ),
                BuyConfirmDetailRow(
                  label: context.loc.buyConfirmPayoutMethod,
                  value: payoutMethod,
                ),
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
            mainAxisSize: .min,
            children: [
              if (isConfirmingOrder || isRefreshingOrder)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  mainAxisAlignment: .center,
                  children: [
                    Text(
                      context.loc.buyConfirmAwaitingConfirmation,
                      style: context.font.bodyMedium?.copyWith(
                        fontWeight: .w500,
                        color: context.appColors.outline,
                      ),
                    ),
                    const Gap(4),
                    Countdown(
                      until: buyOrder.confirmationDeadline,
                      onTimeout: () {
                        context.read<BuyBloc>().add(
                          const BuyEvent.refreshOrder(),
                        );
                      },
                    ),
                  ],
                ),
              const Gap(16),
              BBButton.big(
                label: context.loc.buyConfirmPurchase,
                disabled: isConfirmingOrder || isRefreshingOrder,
                onPressed: () {
                  context.read<BuyBloc>().add(const BuyEvent.confirmOrder());
                },
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
