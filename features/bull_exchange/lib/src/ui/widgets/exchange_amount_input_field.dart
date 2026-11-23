import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmountInputFormatter,
        BullShapesX,
        BullShimmerLine,
        Gap,
        BullTypographyX;
import 'package:intl/intl.dart';

import '../../exchange_l10n.dart';

class ExchangeAmountInputField extends StatelessWidget {
  const ExchangeAmountInputField({
    super.key,
    this._isLoading = false,
    this._bitcoinUnit,
    required this._amountController,
    this._focusNode,
    this._isFiatCurrencyInput = true,
    this._fiatCurrency,
    this._onIsFiatCurrencyInputChanged,
    this._fiatBalance,
    this._canExceedBalance = false,
  });

  final bool _isLoading;
  final BitcoinUnit? _bitcoinUnit;
  final TextEditingController _amountController;
  final FocusNode? _focusNode;
  final bool _isFiatCurrencyInput;
  final FiatCurrency? _fiatCurrency;
  final void Function(bool isFiat)? _onIsFiatCurrencyInputChanged;
  final UserBalance? _fiatBalance;
  final bool _canExceedBalance;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final amountInputDecimals = _isFiatCurrencyInput
        ? _fiatCurrency?.decimals
        : _bitcoinUnit?.decimals;
    final inputCurrency = _isFiatCurrencyInput
        ? _fiatCurrency?.code
        : _bitcoinUnit?.code;
    final alternateCurrency = _isFiatCurrencyInput
        ? _bitcoinUnit?.code
        : _fiatCurrency?.code;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(loc.exchangeAmountInputTitle, style: context.bullType.body),
        const Gap(4.0),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.bullShapes.input),
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
                if (_isLoading ||
                    inputCurrency == null ||
                    amountInputDecimals == null)
                  const BullShimmerLine(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                  )
                else
                  Row(
                    mainAxisSize: .min,
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          focusNode: _focusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            BullAmountInputFormatter(
                              inputCurrency,
                              maxDecimals: amountInputDecimals,
                            ),
                          ],
                          style: context.bullType.headline.copyWith(
                            color: context.appColors.primary,
                          ),
                          decoration: InputDecoration(
                            hintText: NumberFormat.decimalPatternDigits(
                              decimalDigits: amountInputDecimals,
                            ).format(0),
                            hintStyle: context.bullType.headline.copyWith(
                              color: context.appColors.primary,
                            ),
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return loc.exchangeAmountInputValidationEmpty;
                            }

                            if (_isFiatCurrencyInput ||
                                _bitcoinUnit == BitcoinUnit.btc) {
                              final amount = double.tryParse(value);
                              if (amount == null) {
                                return loc.exchangeAmountInputValidationInvalid;
                              } else if (amount <= 0) {
                                return loc.exchangeAmountInputValidationZero;
                              }
                            } else if (int.tryParse(value) == null) {
                              return loc.exchangeAmountInputValidationInvalid;
                            } else if (int.parse(value) <= 0) {
                              return loc.exchangeAmountInputValidationZero;
                            }
                            if (!_canExceedBalance &&
                                _isFiatCurrencyInput &&
                                _fiatBalance != null) {
                              final amount = double.parse(value);
                              if (amount > _fiatBalance.amount) {
                                return loc
                                    .exchangeAmountInputValidationInsufficient;
                              }
                            }

                            return null;
                          },
                        ),
                      ),
                      const Gap(8.0),
                      Text(
                        inputCurrency,
                        style: context.bullType.headline.copyWith(
                          color: context.appColors.primary,
                        ),
                      ),
                    ],
                  ),

                if (_onIsFiatCurrencyInputChanged != null) ...[
                  const Gap(16),
                  if (_isLoading)
                    const BullShimmerLine(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                    )
                  else if (alternateCurrency != null)
                    Row(
                      mainAxisAlignment: .start,
                      mainAxisSize: .min,
                      children: [
                        IconButton(
                          tooltip: loc.exchangeCurrencyDropdownTitle,
                          onPressed: () {
                            _onIsFiatCurrencyInputChanged(
                              !_isFiatCurrencyInput,
                            );
                            // Clear the amount input when switching currency type
                            // manually to avoid confusion with the previous input
                            // and since the input formatters will change.
                            _amountController.clear();
                          },
                          icon: Icon(
                            Icons.swap_vert,
                            color: context.appColors.outline,
                          ),
                        ),
                        const Gap(8.0),
                        Text(
                          alternateCurrency,
                          style: context.bullType.body.copyWith(
                            color: context.appColors.outline,
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
