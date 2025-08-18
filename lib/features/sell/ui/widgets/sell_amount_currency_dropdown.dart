import 'package:bb_mobile/features/exchange/ui/widgets/exchange_amount_currency_dropdown.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SellAmountCurrencyDropdown extends StatelessWidget {
  const SellAmountCurrencyDropdown({
    super.key,
    String? selectedCurrency,
    required ValueChanged<String> onCurrencyChanged,
  }) : _selectedCurrency = selectedCurrency,
       _onCurrencyChanged = onCurrencyChanged;

  final String? _selectedCurrency;
  final ValueChanged<String> _onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (SellBloc bloc) => bloc.state is SellInitialState,
    );
    final fiatCurrency = context.select((SellBloc bloc) {
      return bloc.state.fiatCurrency;
    });

    return ExchangeAmountCurrencyDropdown(
      isLoading: isLoading,
      initialCurrency: fiatCurrency,
      selectedCurrency: _selectedCurrency,
      onCurrencyChanged: _onCurrencyChanged,
    );
  }
}
