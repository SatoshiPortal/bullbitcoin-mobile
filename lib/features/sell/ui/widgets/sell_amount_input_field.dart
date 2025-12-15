import 'package:bb_mobile/core_deprecated/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
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
    final bitcoinUnit =
        context.select((SellBloc bloc) {
          return bloc.state.bitcoinUnit;
        }) ??
        BitcoinUnit.btc;
    final fiatCurrency =
        _fiatCurrency ??
        context.select((SellBloc bloc) {
          return bloc.state.fiatCurrency;
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
