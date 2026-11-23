import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/dca/presentation/dca_bloc.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class DcaAmountInputFields extends StatelessWidget {
  const DcaAmountInputFields({
    super.key,
    required this.amountController,
    required this.focusNode,
    this.fiatCurrency,
    required this.onFiatCurrencyChanged,
  });

  final TextEditingController amountController;
  final FocusNode focusNode;
  final FiatCurrency? fiatCurrency;
  final void Function(FiatCurrency fiatCurrency) onFiatCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (DcaBloc bloc) => bloc.state is DcaInitialState,
    );
    final balances = context.select((DcaBloc bloc) => bloc.state.balances);

    return Column(
      children: [
        ExchangeAmountInputField(
          isLoading: isLoading,
          amountController: amountController,
          focusNode: focusNode,
          fiatCurrency: fiatCurrency,
          fiatBalance: balances
              .where((b) => b.currencyCode == fiatCurrency?.code)
              .firstOrNull,
          canExceedBalance: false,
        ),
        const Gap(16.0),
        ExchangeAmountCurrencyDropdown(
          isLoading: isLoading,
          currencies: balances
              .map((b) => FiatCurrency.fromCode(b.currencyCode))
              .toList(),
          initialCurrency: fiatCurrency,
          selectedCurrency: fiatCurrency?.code,
          onCurrencyChanged: (String currencyCode) {
            final newFiatCurrency = FiatCurrency.fromCode(currencyCode);
            onFiatCurrencyChanged(newFiatCurrency);
          },
          balances: balances,
        ),
      ],
    );
  }
}
