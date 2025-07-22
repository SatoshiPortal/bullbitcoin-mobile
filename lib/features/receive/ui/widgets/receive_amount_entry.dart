import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
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
      error: amountException?.message,
    );
  }
}
