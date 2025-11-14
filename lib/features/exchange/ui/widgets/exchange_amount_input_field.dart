import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
class ExchangeAmountInputField extends StatelessWidget {
  const ExchangeAmountInputField({
    super.key,
    bool isLoading = false,
    BitcoinUnit? bitcoinUnit,
    required TextEditingController amountController,
    bool isFiatCurrencyInput = true,
    FiatCurrency? fiatCurrency,
    void Function(bool isFiat)? onIsFiatCurrencyInputChanged,
    UserBalance? fiatBalance,
    bool canExceedBalance = false,
  }) : _isLoading = isLoading,
       _bitcoinUnit = bitcoinUnit,
       _amountController = amountController,
       _isFiatCurrencyInput = isFiatCurrencyInput,
       _fiatCurrency = fiatCurrency,
       _onIsFiatCurrencyInputChanged = onIsFiatCurrencyInputChanged,
       _fiatBalance = fiatBalance,
       _canExceedBalance = canExceedBalance;

  final bool _isLoading;
  final BitcoinUnit? _bitcoinUnit;
  final TextEditingController _amountController;
  final bool _isFiatCurrencyInput;
  final FiatCurrency? _fiatCurrency;
  final void Function(bool isFiat)? _onIsFiatCurrencyInputChanged;
  final UserBalance? _fiatBalance;
  final bool _canExceedBalance;

  @override
  Widget build(BuildContext context) {
    final amountInputDecimals =
        _isFiatCurrencyInput
            ? _fiatCurrency?.decimals ?? 2
            : _bitcoinUnit!.decimals;
    final inputCurrency =
        _isFiatCurrencyInput
            ? _fiatCurrency?.code ?? 'CAD'
            : _bitcoinUnit?.code ?? 'BTC';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.loc.exchangeAmountInputTitle, style: context.font.bodyMedium),
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
                if (_isLoading)
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
                          inputFormatters: [
                            AmountInputFormatter(inputCurrency),
                          ],
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
                              return context.loc.exchangeAmountInputValidationEmpty;
                            }

                            if (_isFiatCurrencyInput ||
                                _bitcoinUnit == BitcoinUnit.btc) {
                              final amount = double.tryParse(value);
                              if (amount == null) {
                                return context.loc.exchangeAmountInputValidationInvalid;
                              } else if (amount <= 0) {
                                return context.loc.exchangeAmountInputValidationZero;
                              }
                            } else if (int.tryParse(value) == null) {
                              return context.loc.exchangeAmountInputValidationInvalid;
                            } else if (int.parse(value) <= 0) {
                              return context.loc.exchangeAmountInputValidationZero;
                            }
                            if (!_canExceedBalance &&
                                _isFiatCurrencyInput &&
                                _fiatBalance != null) {
                              final amount = double.parse(value);
                              if (amount > _fiatBalance.amount) {
                                return context.loc.exchangeAmountInputValidationInsufficient;
                              }
                            }

                            return null;
                          },
                        ),
                      ),
                      const Gap(8.0),
                      Text(
                        _bitcoinUnit == null
                            ? _fiatCurrency!.code
                            : _isFiatCurrencyInput
                            ? _fiatCurrency!.code
                            : _bitcoinUnit.code,
                        style: context.font.displaySmall?.copyWith(
                          color: context.colour.primary,
                        ),
                      ),
                    ],
                  ),

                if (_onIsFiatCurrencyInputChanged != null) ...[
                  const Gap(16),
                  if (_isLoading)
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
                            _onIsFiatCurrencyInputChanged(
                              !_isFiatCurrencyInput,
                            );
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
                              ? _bitcoinUnit?.code ?? BitcoinUnit.btc.code
                              : _fiatCurrency!.code,
                          style: context.font.bodyMedium?.copyWith(
                            color: context.colour.outline,
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
