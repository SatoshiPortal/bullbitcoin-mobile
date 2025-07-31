import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_amount_input_field.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SellAmountInputField extends StatelessWidget {
  const SellAmountInputField({
    super.key,
    required TextEditingController amountController,
    required bool isFiatCurrencyInput,
    FiatCurrency? fiatCurrency,
    required void Function(bool isFiat) onIsFiatCurrencyInputChanged,
  }) : _amountController = amountController,
       _isFiatCurrencyInput = isFiatCurrencyInput,
       _fiatCurrency = fiatCurrency,
       _onIsFiatCurrencyInputChanged = onIsFiatCurrencyInputChanged;

  final TextEditingController _amountController;
  final bool _isFiatCurrencyInput;
  final FiatCurrency? _fiatCurrency;
  final void Function(bool isFiat) _onIsFiatCurrencyInputChanged;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select(
      (SellBloc bloc) => bloc.state is SellInitialState,
    );
    final bitcoinUnit = context.select((SellBloc bloc) {
      final state = bloc.state;
      if (state is SellAmountInputState) return state.bitcoinUnit;
      if (state is SellWalletSelectionState) return state.bitcoinUnit;
      return BitcoinUnit.btc;
    });
    final fiatCurrency =
        _fiatCurrency ??
        context.select((SellBloc bloc) {
          final state = bloc.state;
          if (state is SellAmountInputState) {
            return FiatCurrency.fromCode(state.userSummary.currency ?? 'CAD');
          }
          if (state is SellWalletSelectionState) {
            return state.fiatCurrency;
          }
          return FiatCurrency.cad;
        });

    return ExchangeAmountInputField(
      isLoading: isLoading,
      bitcoinUnit: bitcoinUnit,
      amountController: _amountController,
      isFiatCurrencyInput: _isFiatCurrencyInput,
      fiatCurrency: fiatCurrency,
      onIsFiatCurrencyInputChanged: _onIsFiatCurrencyInputChanged,
    );
  }
}
