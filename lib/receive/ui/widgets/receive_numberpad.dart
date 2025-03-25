import 'package:bb_mobile/_ui/components/dialpad/dialPad.dart';
import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveNumberPad extends StatelessWidget {
  const ReceiveNumberPad({super.key});

  @override
  Widget build(BuildContext context) {
    return DialPad(
      onNumberPressed: (number) {
        final amountInput = context.read<ReceiveBloc>().state.amountInput;
        final amount = amountInput + number;
        context.read<ReceiveBloc>().add(ReceiveAmountChanged(amount));
      },
      onBackspacePressed: () {
        final amountInput = context.read<ReceiveBloc>().state.amountInput;
        if (amountInput.isNotEmpty) {
          final amount = amountInput.substring(0, amountInput.length - 1);
          context.read<ReceiveBloc>().add(ReceiveAmountChanged(amount));
        }
      },
    );
  }
}
