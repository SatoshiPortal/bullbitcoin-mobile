import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/ui/components/price_input/price_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveAmountEntry extends StatefulWidget {
  const ReceiveAmountEntry({
    super.key,
    required this.amountController,
    required this.focusNode,
  });

  final TextEditingController amountController;
  final FocusNode focusNode;

  @override
  State<ReceiveAmountEntry> createState() => _ReceiveAmountEntryState();
}

class _ReceiveAmountEntryState extends State<ReceiveAmountEntry> {
  @override
  Widget build(BuildContext context) {
    final inputCurrency = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.inputAmountCurrencyCode,
    );
    final availableInputCurrencies = context.select<ReceiveBloc, List<String>>(
      (bloc) => bloc.state.inputAmountCurrencyCodes,
    );
    final amountEquivalent = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.formattedAmountInputEquivalent,
    );
    final amountException = context.select<ReceiveBloc, AmountException?>(
      (bloc) => bloc.state.amountException,
    );
    final bitcoinUnit = context.select(
      (ReceiveBloc cubit) =>
          cubit.state.isInputAmountFiat
              ? cubit.state.bitcoinUnit
              : BitcoinUnit.fromCode(cubit.state.inputAmountCurrencyCode),
    );

    return PriceInput(
      currency: inputCurrency,
      amountEquivalent: amountEquivalent,
      availableCurrencies: availableInputCurrencies,
      amountController: widget.amountController,
      focusNode: widget.focusNode,
      onNoteChanged: (note) {
        context.read<ReceiveBloc>().add(ReceiveNoteChanged(note));
      },
      onCurrencyChanged: (currencyCode) {
        context.read<ReceiveBloc>().add(
          ReceiveAmountCurrencyChanged(currencyCode),
        );
      },
      error:
          amountException != null
              ? amountException is BelowSwapLimitAmountException
                  ? 'Minimum swap amount is ${bitcoinUnit == BitcoinUnit.sats ? FormatAmount.sats(amountException.limitAmountSat) : FormatAmount.btc(ConvertAmount.satsToBtc(amountException.limitAmountSat))}'
                  : amountException is AboveSwapLimitAmountException
                  ? 'Maximum swap amount is ${bitcoinUnit == BitcoinUnit.sats ? FormatAmount.sats(amountException.limitAmountSat) : FormatAmount.btc(ConvertAmount.satsToBtc(amountException.limitAmountSat))}'
                  : amountException is AboveBitcoinProtocolLimitAmountException
                  ? 'Amount above Bitcoin protocol limit.'
                  : null
              : null,
    );
  }
}
