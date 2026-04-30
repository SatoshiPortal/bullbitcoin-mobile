import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveAmountEntry extends StatefulWidget {
  const ReceiveAmountEntry({super.key});

  @override
  State<ReceiveAmountEntry> createState() => _ReceiveAmountEntryState();
}

class _ReceiveAmountEntryState extends State<ReceiveAmountEntry> {
  late final TextEditingController _amountController;
  late final FocusNode _amountFocusNode;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ReceiveBloc>();
    _amountController = TextEditingController(text: bloc.state.inputAmount);
    _amountController.addListener(() {
      final text = _amountController.text;
      if (text != bloc.state.inputAmount) {
        bloc.add(ReceiveAmountInputChanged(text));
      }
    });
    _amountFocusNode = FocusNode();
    _amountFocusNode.addListener(() {
      if (!_amountFocusNode.hasFocus) {
        // Reset selection to end without showing the cursor when the field
        // loses focus.
        final currentText = _amountController.text;
        _amountController.value = TextEditingValue(
          text: currentText,
          selection: TextSelection.collapsed(offset: currentText.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

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

    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen: (previous, current) =>
          previous.inputAmountCurrencyCode != current.inputAmountCurrencyCode,
      listener: (_, _) => _amountController.clear(),
      child: PriceInput(
        currency: inputCurrency,
        amountEquivalent: amountEquivalent,
        availableCurrencies: availableInputCurrencies,
        amountController: _amountController,
        focusNode: _amountFocusNode,
        onCurrencyChanged: (currencyCode) {
          context.read<ReceiveBloc>().add(
            ReceiveAmountCurrencyChanged(currencyCode),
          );
        },
        error: amountException?.message,
      ),
    );
  }
}
