import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveNumberPad extends StatelessWidget {
  const ReceiveNumberPad({super.key, required this.amountController});

  final TextEditingController amountController;

  @override
  Widget build(BuildContext context) {
    final inputCurrency = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.inputAmountCurrencyCode,
    );

    return AmountDialPad(
      controller: amountController,
      inputCurrencyCode: inputCurrency,
    );
  }
}
