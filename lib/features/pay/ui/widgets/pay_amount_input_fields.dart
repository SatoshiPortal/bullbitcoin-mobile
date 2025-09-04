import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_amount_currency_dropdown.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_amount_input_field.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class PayAmountInputFields extends StatelessWidget {
  const PayAmountInputFields({
    super.key,
    required this.amountController,
    required this.fiatCurrency,
    required this.onFiatCurrencyChanged,
  });

  final TextEditingController amountController;
  final FiatCurrency fiatCurrency;
  final void Function(FiatCurrency fiatCurrency) onFiatCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (PayBloc bloc) => bloc.state is PayInitialState,
    );

    return Column(
      children: [
        ExchangeAmountInputField(
          isLoading: isLoading,
          amountController: amountController,
          fiatCurrency: fiatCurrency,
        ),
        const Gap(16.0),
        ExchangeAmountCurrencyDropdown(
          isLoading: isLoading,
          initialCurrency: fiatCurrency,
          selectedCurrency: fiatCurrency.code,
          onCurrencyChanged: (String currencyCode) {
            final newFiatCurrency = FiatCurrency.fromCode(currencyCode);
            onFiatCurrencyChanged(newFiatCurrency);
          },
        ),
      ],
    );
  }
}
