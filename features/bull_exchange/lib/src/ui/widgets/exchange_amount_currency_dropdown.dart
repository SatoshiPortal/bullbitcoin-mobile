import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDropdown, BullPickerItem, BullShimmerLine, Gap, BullTypographyX;

import '../../exchange_l10n.dart';

class ExchangeAmountCurrencyDropdown extends StatelessWidget {
  const ExchangeAmountCurrencyDropdown({
    super.key,
    this.isLoading = false,
    this.currencies = FiatCurrency.values,
    this.initialCurrency,
    this.selectedCurrency,
    required this.onCurrencyChanged,
    this.balances,
  });

  final bool isLoading;
  final List<FiatCurrency> currencies;
  final FiatCurrency? initialCurrency;
  final FiatCurrency? selectedCurrency;
  final ValueChanged<FiatCurrency> onCurrencyChanged;
  final List<UserBalance>? balances;

  String _label(FiatCurrency currency) {
    final balance = balances
        ?.where((b) => b.currencyCode == currency.code)
        .firstOrNull;
    if (balance == null) return '${currency.symbol} ${currency.code}';
    final amount = FormatAmount.fiat(
      balance.amount,
      currency.code,
      simpleFormat: true,
    );
    return '${currency.symbol} ${currency.code} - $amount';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          context.loc.exchangeCurrencyDropdownTitle,
          style: context.bullType.body,
        ),
        const Gap(4.0),
        if (isLoading)
          const SizedBox(height: 56, child: Center(child: BullShimmerLine()))
        else
          BullDropdown<FiatCurrency>(
            value: selectedCurrency ?? initialCurrency,
            items: [
              for (final currency in currencies)
                BullPickerItem(value: currency, label: _label(currency)),
            ],
            onChanged: onCurrencyChanged,
            validator: (value) {
              if (value == null) {
                return context.loc.exchangeCurrencyDropdownValidation;
              }
              return null;
            },
          ),
      ],
    );
  }
}
