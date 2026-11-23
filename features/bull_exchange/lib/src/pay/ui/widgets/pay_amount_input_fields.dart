import 'package:exchange/exchange.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class PayAmountInputFields extends StatelessWidget {
  const PayAmountInputFields({
    super.key,
    required this.amountController,
    required this.focusNode,
    required this.fiatCurrency,
    this.onFiatCurrencyChanged,
  });

  final TextEditingController amountController;
  final FocusNode focusNode;
  final FiatCurrency fiatCurrency;
  final void Function(FiatCurrency fiatCurrency)? onFiatCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExchangeAmountInputField(
          amountController: amountController,
          focusNode: focusNode,
          fiatCurrency: fiatCurrency,
        ),
        if (onFiatCurrencyChanged != null) ...[
          const Gap(16.0),
          ExchangeAmountCurrencyDropdown(
            initialCurrency: fiatCurrency,
            selectedCurrency: fiatCurrency,
            onCurrencyChanged: onFiatCurrencyChanged!,
          ),
        ],
      ],
    );
  }
}
