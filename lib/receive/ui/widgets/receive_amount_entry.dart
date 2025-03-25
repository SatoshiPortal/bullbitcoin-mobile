import 'package:bb_mobile/_ui/components/price_input/price_input.dart';
import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveAmountEntry extends StatelessWidget {
  const ReceiveAmountEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final amount = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.amountInput,
    );
    final inputCurrency = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.amountInputCurrencyCode,
    );
    final availableInputCurrencies = context.select<ReceiveBloc, List<String>>(
      (bloc) => bloc.state.amountInputCurrencyCodes,
    );
    final amountEquivalent = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.formattedAmountEquivalent,
    );

    return PriceInput(
      amount: amount,
      currency: inputCurrency,
      amountEquivalent: amountEquivalent,
      availableCurrencies: availableInputCurrencies,
      onCurrencyChanged: (currencyCode) {
        context
            .read<ReceiveBloc>()
            .add(ReceiveAmountCurrencyChanged(currencyCode));
      },
    );
  }
}
