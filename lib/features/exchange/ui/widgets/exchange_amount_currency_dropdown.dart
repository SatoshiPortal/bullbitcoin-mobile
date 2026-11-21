import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDropdown, BullPickerItem, BullShimmerLine, Gap, BullTypographyX;

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
  final String? selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;
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
          BullDropdown<String>(
            value: selectedCurrency ?? initialCurrency?.code,
            items: [
              for (final currency in currencies)
                BullPickerItem(value: currency.code, label: _label(currency)),
            ],
            onChanged: onCurrencyChanged,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.loc.exchangeCurrencyDropdownValidation;
              }
              return null;
            },
          ),
      ],
    );
  }
}
