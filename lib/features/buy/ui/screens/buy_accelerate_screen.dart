import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_confirm_detail_row.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class BuyAccelerateScreen extends StatelessWidget {
  const BuyAccelerateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAcceleratingOrder = context.select(
      (BuyBloc bloc) => bloc.state.isAcceleratingOrder,
    );
    final fees = context.select(
      (BuyBloc bloc) => bloc.state.accelerationNetworkFees,
    );
    final relativeFee = fees?.fastest.value as double?;
    final formattedRelativeFee =
        relativeFee != null ? '${relativeFee.toStringAsFixed(2)} sat/vB' : null;
    final absoluteFee = fees?.toAbsolute(140).fastest.value as int?;
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit,
    );
    final formattedAbsoluteFee =
        absoluteFee != null && bitcoinUnit != null
            ? bitcoinUnit == BitcoinUnit.sats
                ? FormatAmount.sats(absoluteFee)
                : FormatAmount.btc(ConvertAmount.satsToBtc(absoluteFee))
            : null;

    final currencyCode = context.select(
      (BuyBloc bloc) => bloc.state.buyOrder?.payinCurrency,
    );
    final exchangeRate = context.select(
      (BuyBloc bloc) => bloc.state.exchangeRate,
    );
    final absoluteFeeFiatEstimate =
        absoluteFee != null && exchangeRate > 0
            ? ConvertAmount.satsToFiat(absoluteFee, exchangeRate)
            : null;
    final formattedFeeFiatEstimate =
        absoluteFeeFiatEstimate != null && currencyCode != null
            ? FormatAmount.fiat(absoluteFeeFiatEstimate, currencyCode)
            : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        Navigator.of(context, rootNavigator: true).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.loc.buyConfirmExpressWithdrawal)),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    context.loc.buyNetworkFeeExplanation,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.appColors.text,
                    ),
                  ),
                  const SizedBox(height: 32),
                  BuyConfirmDetailRow(
                    label: context.loc.buyNetworkFees,
                    value: formattedAbsoluteFee,
                  ),
                  BuyConfirmDetailRow(
                    label: context.loc.buyEstimatedFeeValue,
                    value: formattedFeeFiatEstimate,
                  ),
                  BuyConfirmDetailRow(
                    label: context.loc.buyNetworkFeeRate,
                    value: formattedRelativeFee,
                  ),
                  BuyConfirmDetailRow(
                    label: context.loc.buyConfirmationTime,
                    value: context.loc.buyConfirmationTimeValue,
                  ),
                  const SizedBox(height: 32),
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
                if (isAcceleratingOrder)
                  const Center(child: CircularProgressIndicator())
                else
                  BBButton.big(
                    label: context.loc.buyWaitForFreeWithdrawal,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                    bgColor: context.appColors.surface,
                    textColor: context.appColors.secondary,
                  ),
                const Gap(16),
                BBButton.big(
                  label: context.loc.buyConfirmExpress,
                  disabled: isAcceleratingOrder,
                  onPressed: () {
                    context.read<BuyBloc>().add(
                      const BuyEvent.accelerateTransactionConfirmed(),
                    );
                  },
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
