import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ExchangeAmountCurrencyDropdown extends StatelessWidget {
  const ExchangeAmountCurrencyDropdown({
    super.key,
    this.isLoading = false,
    this.currencies = FiatCurrency.values,
    this.initialCurrency = FiatCurrency.cad,
    this.selectedCurrency,
    required this.onCurrencyChanged,
    this.balances,
  });

  final bool isLoading;
  final List<FiatCurrency> currencies;
  final FiatCurrency initialCurrency;
  final String? selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;
  final List<UserBalance>? balances;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select currency', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child:
                  isLoading
                      ? const LoadingLineContent()
                      : DropdownButtonFormField<String>(
                        value: selectedCurrency ?? initialCurrency.code,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ),
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: context.colour.secondary,
                        ),
                        items:
                            currencies.map((currency) {
                              final balance =
                                  balances
                                      ?.where(
                                        (b) => b.currencyCode == currency.code,
                                      )
                                      .firstOrNull;
                              return DropdownMenuItem<String>(
                                value: currency.code,
                                child: Text(
                                  '${currency.symbol} ${currency.code} ${balance != null ? '- ${FormatAmount.fiat(balance.amount, currency.code, simpleFormat: true)}' : ''}',
                                  style: context.font.headlineSmall,
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            onCurrencyChanged(value);
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a currency';
                          }
                          return null;
                        },
                      ),
            ),
          ),
        ),
      ],
    );
  }
}
