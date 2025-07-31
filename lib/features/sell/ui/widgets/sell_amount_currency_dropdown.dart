import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
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
      final state = bloc.state;
      if (state is SellAmountInputState) {
        return FiatCurrency.fromCode(state.userSummary.currency ?? 'CAD');
      }
      if (state is SellWalletSelectionState) {
        return state.fiatCurrency;
      }
      return FiatCurrency.cad;
    });

    return ExchangeAmountCurrencyDropdown(
      isLoading: isLoading,
      initialCurrency: fiatCurrency,
      selectedCurrency: _selectedCurrency,
      onCurrencyChanged: _onCurrencyChanged,
    );
  }
}
