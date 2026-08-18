import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/buy_payout_method_label.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_confirm_detail_row.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

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
    // A buy order always carries a rate, but the model no longer guarantees one,
    // so derive it from the two amounts rather than crash the screen.
    final formattedExchangeRate = FormatAmount.fiat(
      buyOrder.exchangeRateAmount ??
          (payoutAmountBtc > 0 ? buyOrder.payinAmount / payoutAmountBtc : 0.0),
      buyOrder.exchangeRateCurrency ?? buyOrder.payinCurrency,
    );
    final externalBitcoinWalletLabel = context.loc.buyConfirmExternalWallet;
    final selectedWallet = context.select(
      (BuyBloc bloc) => bloc.state.selectedWallet,
    );
    final payoutWallet = selectedWallet == null
        ? externalBitcoinWalletLabel
        : selectedWallet.displayLabel(context);
    // With no wallet of ours selected the payout goes to an address the user
    // pasted, so the order itself is the only source for the network.
    final payoutMethod = buyPayoutMethodLabel(
      context,
      isLiquid: selectedWallet?.network.isLiquid ?? buyOrder.isLiquid,
    );

    final isConfirmingOrder = context.select(
      (BuyBloc bloc) => bloc.state.isConfirmingOrder,
    );
    final isRefreshingOrder = context.select(
      (BuyBloc bloc) => bloc.state.isRefreshingOrder,
    );
    return BullPage(
      topBar: BullTopBar(
        title: context.loc.buyConfirmTitle,
        onBack: context.pop,
      ),
      safeArea: false,
      child: SafeArea(
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
                  child: BullText(
                    formattedPayInAmount,
                    style: context.font.displaySmall,
                    color: context.appColors.secondary,
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
                  label: context.loc.buyConfirmPayoutWallet,
                  value: payoutWallet,
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
      bottomBar: SafeArea(
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
                    if (buyOrder.confirmationDeadline case final deadline?)
                      Countdown(
                        until: deadline,
                        onTimeout: () {
                          context.read<BuyBloc>().add(
                            const BuyEvent.refreshOrder(),
                          );
                        },
                      ),
                  ],
                ),
              const Gap(16),
              BullButton.primary(
                label: context.loc.buyConfirmPurchase,
                disabled: isConfirmingOrder || isRefreshingOrder,
                onPressed: () {
                  context.read<BuyBloc>().add(const BuyEvent.confirmOrder());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
