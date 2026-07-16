import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class SwapAmountInput extends StatelessWidget {
  const SwapAmountInput({
    super.key,
    required this.amountController,
    required this.focusNode,
  });

  final TextEditingController amountController;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransferBloc>().state;
    final inputCurrency = state.inputAmountCurrencyCode;
    final amountInputDecimals = state.isInputAmountFiat
        ? 2
        : inputCurrency == BitcoinUnit.btc.code
        ? BitcoinUnit.btc.decimals
        : 0;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(context.loc.swapAmountLabel, style: context.font.bodyMedium),
        const Gap(4),
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
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                if (state.isStarting)
                  const LoadingLineContent(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  )
                else
                  Row(
                    mainAxisSize: .min,
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: amountController,
                          focusNode: focusNode,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: amountInputDecimals > 0,
                          ),
                          inputFormatters: [
                            AmountInputFormatter(inputCurrency),
                          ],
                          style: context.font.displaySmall?.copyWith(
                            color: context.appColors.primary,
                          ),
                          decoration: InputDecoration(
                            hintText: NumberFormat.decimalPatternDigits(
                              decimalDigits: amountInputDecimals,
                            ).format(0),
                            hintStyle: context.font.displaySmall?.copyWith(
                              color: context.appColors.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const Gap(8.0),
                      InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: _pickerCurrencies(state).isEmpty
                            ? null
                            : () => _openCurrencyPicker(context, state),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisSize: .min,
                            children: [
                              Text(
                                state.displayInputAmountCurrencyCode,
                                style: context.font.displaySmall?.copyWith(
                                  color: context.appColors.primary,
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: context.appColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                const Gap(16),
                if (state.isStarting)
                  const LoadingLineContent(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  )
                else
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _toggleCurrencyType(context, state),
                        child: Icon(
                          Icons.swap_vert,
                          color: context.appColors.outline,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        state.amount.isEmpty
                            ? state.displayEquivalentCurrencyCode
                            : '~${state.formattedInputAmountEquivalent}',
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.outline,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 48),
                          tapTargetSize: .padded,
                        ),
                        onPressed:
                            state.maxAmountSat == null ||
                                state.maxAmountSat! <= 0
                            ? null
                            : () {
                                context.read<TransferBloc>().add(
                                  const TransferEvent.maxAmountSelected(),
                                );
                              },
                        child: Text(
                          context.loc.swapMaxButton,
                          style: context.font.bodyMedium?.copyWith(
                            color: context.appColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (state.amountValidationError != null ||
            state.isInsufficientBalance) ...[
          const Gap(8),
          Text(
            state.amountValidationError ?? context.loc.swapInsufficientFunds,
            style: context.font.labelLarge?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openCurrencyPicker(
    BuildContext context,
    TransferState state,
  ) async {
    focusNode.unfocus();
    final selected = await BlurredBottomSheet.show<String?>(
      context: context,
      child: CurrencyBottomSheet(
        availableCurrencies: _pickerCurrencies(state),
        selectedValue: state.displayInputAmountCurrencyCode,
      ),
    );
    if (selected == null || !context.mounted) return;
    context.read<TransferBloc>().add(
      TransferEvent.amountCurrencyChanged(_currencyCode(selected)),
    );
  }

  void _toggleCurrencyType(BuildContext context, TransferState state) {
    final currencyCode = state.isInputAmountFiat
        ? state.bitcoinUnit.code
        : state.fiatCurrencyCode;
    if (currencyCode == null || currencyCode.isEmpty) return;
    focusNode.unfocus();
    context.read<TransferBloc>().add(
      TransferEvent.amountCurrencyChanged(currencyCode),
    );
  }

  List<String> _pickerCurrencies(TransferState state) {
    if (state.isInputAmountFiat) return state.fiatCurrencyCodes;
    final prefix = (state.fromWallet?.isLiquid ?? false) ? 'L-' : '';
    return [
      '$prefix${BitcoinUnit.btc.code}',
      '$prefix${BitcoinUnit.sats.code}',
    ];
  }

  String _currencyCode(String displayCode) {
    return displayCode.startsWith('L-')
        ? displayCode.substring(2)
        : displayCode;
  }
}
