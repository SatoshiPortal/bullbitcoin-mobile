import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/ui/components/dialpad/dial_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveNumberPad extends StatelessWidget {
  const ReceiveNumberPad({super.key});

  @override
  Widget build(BuildContext context) {
    return DialPad(
      onNumberPressed: (number) {
        final inputAmount = context.read<ReceiveBloc>().state.inputAmount;
        final amount = inputAmount + number;
        context.read<ReceiveBloc>().add(ReceiveAmountInputChanged(amount));
      },
      onBackspacePressed: () {
        final inputAmount = context.read<ReceiveBloc>().state.inputAmount;
        if (inputAmount.isNotEmpty) {
          final amount = inputAmount.substring(0, inputAmount.length - 1);
          context.read<ReceiveBloc>().add(ReceiveAmountInputChanged(amount));
        }
      },
    );
  }
}
