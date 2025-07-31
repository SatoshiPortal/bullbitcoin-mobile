import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class SellAmountInputField extends StatelessWidget {
  const SellAmountInputField({
    super.key,
    required TextEditingController amountController,
    required bool isFiatCurrencyInput,
    FiatCurrency? fiatCurrency,
    required void Function(bool isFiat) onIsFiatCurrencyInputChanged,
  }) : _amountController = amountController,
       _isFiatCurrencyInput = isFiatCurrencyInput,
       _fiatCurrency = fiatCurrency,
       _onIsFiatCurrencyInputChanged = onIsFiatCurrencyInputChanged;

  final TextEditingController _amountController;
  final bool _isFiatCurrencyInput;
  final FiatCurrency? _fiatCurrency;
  final void Function(bool isFiat) _onIsFiatCurrencyInputChanged;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (SellBloc bloc) => bloc.state is SellInitialState,
    );
    final bitcoinUnit =
        context.select((SellBloc bloc) {
          return bloc.state.bitcoinUnit;
        }) ??
        BitcoinUnit.btc;
    final fiatCurrency =
        _fiatCurrency ??
        context.select((SellBloc bloc) {
          return bloc.state.fiatCurrency;
        });
    final amountInputDecimals =
        _isFiatCurrencyInput ? fiatCurrency!.decimals : bitcoinUnit.decimals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter amount', style: context.font.bodyMedium),
        const Gap(4.0),
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
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters:
                              amountInputDecimals > 0
                                  ? [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(
                                        r'^\d+\.?\d{0,'
                                        '$amountInputDecimals'
                                        '}',
                                      ),
                                    ),
                                  ]
                                  : [FilteringTextInputFormatter.digitsOnly],
                          style: context.font.displaySmall?.copyWith(
                            color: context.colour.primary,
                          ),
                          decoration: InputDecoration(
                            hintText: NumberFormat.decimalPatternDigits(
                              decimalDigits: amountInputDecimals,
                            ).format(0),
                            hintStyle: context.font.displaySmall?.copyWith(
                              color: context.colour.primary,
                            ),
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            if (_isFiatCurrencyInput ||
                                bitcoinUnit == BitcoinUnit.btc) {
                              if (double.tryParse(value) == null) {
                                return 'Invalid amount';
                              }
                            } else if (int.tryParse(value) == null) {
                              return 'Invalid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                      const Gap(8.0),
                      Text(
                        _isFiatCurrencyInput
                            ? fiatCurrency!.code
                            : bitcoinUnit.code,
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
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          _onIsFiatCurrencyInputChanged(!_isFiatCurrencyInput);
                          // Clear the amount input when switching currency type
                          // manually to avoid confusion with the previous input
                          // and since the input formatters will change.
                          _amountController.clear();
                        },
                        child: Icon(
                          Icons.swap_vert,
                          color: context.colour.outline,
                        ),
                      ),
                      const Gap(8.0),
                      Text(
                        _isFiatCurrencyInput
                            ? bitcoinUnit.code
                            : fiatCurrency!.code,
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
