import 'dart:math' as math;

import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveNumberPad extends StatelessWidget {
  const ReceiveNumberPad({
    super.key,
    required this.amountController,
    this.focusNode,
  });

  final TextEditingController amountController;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return DialPad(
      onNumberPressed: (number) {
        if (focusNode != null && !focusNode!.hasFocus) {
          focusNode!.requestFocus();

          final currentText = amountController.text;
          amountController.selection = TextSelection.collapsed(
            offset: currentText.length,
          );
        }

        final inputAmount = context.read<ReceiveBloc>().state.inputAmount;

        final selection = amountController.selection;
        final cursorPosition = selection.baseOffset.clamp(
          0,
          inputAmount.length,
        );
        final endPosition = selection.extentOffset.clamp(0, inputAmount.length);

        String newAmount;
        int newCursorPosition;

        if (cursorPosition == endPosition) {
          newAmount =
              inputAmount.substring(0, cursorPosition) +
              number +
              inputAmount.substring(cursorPosition);
          newCursorPosition = cursorPosition + 1;
        } else {
          final start = math.min(cursorPosition, endPosition);
          final end = math.max(cursorPosition, endPosition);
          newAmount =
              inputAmount.substring(0, start) +
              number +
              inputAmount.substring(end);
          newCursorPosition = start + 1;
        }

        final targetCursorPosition = newCursorPosition;

        context.read<ReceiveBloc>().add(ReceiveAmountInputChanged(newAmount));

        amountController.value = TextEditingValue(
          text: newAmount,
          selection: TextSelection.collapsed(offset: targetCursorPosition),
        );
      },
      onBackspacePressed: () {
        if (focusNode != null && !focusNode!.hasFocus) {
          focusNode!.requestFocus();

          final currentText = amountController.text;
          amountController.selection = TextSelection.collapsed(
            offset: currentText.length,
          );
        }

        final inputAmount = context.read<ReceiveBloc>().state.inputAmount;
        if (inputAmount.isEmpty) return;

        final selection = amountController.selection;
        final cursorPosition = selection.baseOffset.clamp(
          0,
          inputAmount.length,
        );
        final endPosition = selection.extentOffset.clamp(0, inputAmount.length);

        String newAmount;
        int newCursorPosition;

        if (cursorPosition == endPosition) {
          if (cursorPosition > 0) {
            newAmount =
                inputAmount.substring(0, cursorPosition - 1) +
                inputAmount.substring(cursorPosition);
            newCursorPosition = cursorPosition - 1;
          } else {
            return;
          }
        } else {
          final start = math.min(cursorPosition, endPosition);
          final end = math.max(cursorPosition, endPosition);
          newAmount =
              inputAmount.substring(0, start) + inputAmount.substring(end);
          newCursorPosition = start;
        }

        final targetCursorPosition = newCursorPosition;

        context.read<ReceiveBloc>().add(ReceiveAmountInputChanged(newAmount));

        amountController.value = TextEditingValue(
          text: newAmount,
          selection: TextSelection.collapsed(offset: targetCursorPosition),
        );
      },
    );
  }
}
