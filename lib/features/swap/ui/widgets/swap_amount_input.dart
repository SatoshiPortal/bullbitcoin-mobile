import 'dart:math';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapAmountInput extends StatelessWidget {
  const SwapAmountInput({
    super.key,
    required this.amountController,
    required this.amountSat,
  });

  final TextEditingController amountController;
  final int amountSat;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (TransferBloc bloc) => bloc.state.isStarting,
    );
    final bitcoinUnit = context.select(
      (TransferBloc bloc) => bloc.state.bitcoinUnit,
    );
    final fromWallet = context.select(
      (TransferBloc bloc) => bloc.state.fromWallet,
    );
    final toWallet = context.select((TransferBloc bloc) => bloc.state.toWallet);
    final fromCurrency = context.select(
      (TransferBloc bloc) => bloc.state.displayFromCurrencyCode,
    );
    final toCurrency = context.select(
      (TransferBloc bloc) => bloc.state.displayToCurrencyCode,
    );
    final swapLimits = context.select(
      (TransferBloc bloc) => bloc.state.swapLimits,
    );
    final estimatedFeesSat = context.select(
      (TransferBloc bloc) => bloc.state.getSwapFeesSat(amountSat),
    );
    final inputAmountSat =
        bitcoinUnit == BitcoinUnit.sats
            ? int.tryParse(amountController.text) ?? 0
            : ConvertAmount.btcToSats(
              double.tryParse(amountController.text) ?? 0,
            );
    final toAmountSat = max(inputAmountSat - estimatedFeesSat, 0);
    final toAmount =
        bitcoinUnit == BitcoinUnit.sats
            ? toAmountSat
            : ConvertAmount.satsToBtc(toAmountSat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transfer amount', style: context.font.bodyLarge),
        const Gap(8),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  const LoadingLineContent(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: amountController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: bitcoinUnit == BitcoinUnit.btc,
                          ),
                          inputFormatters: [
                            AmountInputFormatter(bitcoinUnit.code),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            final inputAmountSat =
                                bitcoinUnit == BitcoinUnit.sats
                                    ? int.tryParse(value) ?? 0
                                    : ConvertAmount.btcToSats(
                                      double.tryParse(value) ?? 0,
                                    );
                            if (inputAmountSat <= 0) {
                              return 'Enter a positive amount';
                            }
                            final balanceSat =
                                fromWallet?.balanceSat.toInt() ?? 0;
                            if ((inputAmountSat + estimatedFeesSat) >
                                balanceSat) {
                              return 'Insufficient balance';
                            }
                            if ((swapLimits?.min ?? 0) > inputAmountSat) {
                              final minAmount =
                                  bitcoinUnit == BitcoinUnit.btc
                                      ? ConvertAmount.satsToBtc(
                                        swapLimits?.min ?? 0,
                                      )
                                      : swapLimits?.min ?? 0;
                              return 'Minimum amount is $minAmount $fromCurrency';
                            }
                            if ((swapLimits?.max ?? double.infinity) <
                                inputAmountSat) {
                              final maxAmount =
                                  bitcoinUnit == BitcoinUnit.btc
                                      ? ConvertAmount.satsToBtc(
                                        swapLimits?.max ?? 0,
                                      )
                                      : swapLimits?.max ?? 0;
                              return 'Maximum amount is $maxAmount $fromCurrency';
                            }
                            return null;
                          },
                          style: context.font.displaySmall?.copyWith(
                            color: context.colour.primary,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: context.font.displaySmall?.copyWith(
                              color: context.colour.primary,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            //context.read<TransferBloc>().amountChanged(value);
                          },
                        ),
                      ),
                      const Gap(8.0),
                      Text(
                        fromCurrency,
                        style: context.font.displaySmall?.copyWith(
                          color: context.colour.primary,
                        ),
                      ),
                    ],
                  ),
                const Gap(16),
                if (isLoading)
                  const LoadingLineContent(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  )
                else
                  Row(
                    children: [
                      InkWell(
                        onTap:
                            toWallet != null && fromWallet != null
                                ? () {
                                  context.read<TransferBloc>().add(
                                    TransferWalletsChanged(
                                      fromWallet: toWallet,
                                      toWallet: fromWallet,
                                    ),
                                  );
                                }
                                : null,
                        child: Icon(
                          Icons.swap_vert,
                          color: context.colour.outline,
                        ),
                      ),
                      const Gap(8.0),
                      Text(
                        '$toAmount $toCurrency',
                        style: context.font.bodyMedium?.copyWith(
                          color: context.colour.outline,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
