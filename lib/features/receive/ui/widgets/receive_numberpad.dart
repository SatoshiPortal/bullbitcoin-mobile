import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveNumberPad extends StatelessWidget {
  const ReceiveNumberPad({super.key, required this.amountController});

  final TextEditingController amountController;

  @override
  Widget build(BuildContext context) {
    return DialPad(
      onNumberPressed: (number) {
        final selectionStart = amountController.selection.baseOffset;
        final selectionEnd = amountController.selection.extentOffset;
        final currentText = amountController.text;
        String newAmount;

        if (selectionStart == -1) {
          // Field is not focused, so just add to the end
          newAmount = currentText + number;
          amountController.text = newAmount;
        } else {
          // Field is focused
          if (selectionStart == selectionEnd) {
            // No selection, insert at cursor
            newAmount =
                currentText.substring(0, selectionStart) +
                number +
                currentText.substring(selectionStart);
          } else {
            // Text is selected, replace selection
            newAmount =
                currentText.substring(0, selectionStart) +
                number +
                currentText.substring(selectionEnd);
          }

          amountController.text = newAmount;
          // Update the cursor position after inserting
          final newCursorPosition = selectionStart + number.length;
          amountController.selection = TextSelection.collapsed(
            offset: newCursorPosition,
          );
        }

        // Finally, inform the bloc of the change
        context.read<ReceiveBloc>().add(ReceiveAmountInputChanged(newAmount));
      },
      onBackspacePressed: () {
        final selectionStart = amountController.selection.baseOffset;
        final selectionEnd = amountController.selection.extentOffset;
        final currentText = amountController.text;
        String newAmount;

        if (selectionStart == -1) {
          // Field is not focused, so just remove from the end
          if (currentText.isNotEmpty) {
            newAmount = currentText.substring(0, currentText.length - 1);
          } else {
            newAmount = currentText;
          }

          amountController.text = newAmount;
        } else {
          // Field is focused
          int newCursorPosition = selectionStart;
          if (selectionStart == selectionEnd) {
            // No selection, remove before cursor
            if (selectionStart > 0) {
              newAmount =
                  currentText.substring(0, selectionStart - 1) +
                  currentText.substring(selectionStart);
              newCursorPosition = selectionStart - 1;
            } else {
              newAmount = currentText;
            }
            amountController.text = newAmount;
          } else {
            // Text is selected, remove selection
            newAmount =
                currentText.substring(0, selectionStart) +
                currentText.substring(selectionEnd);
          }

          amountController.text = newAmount;

          // Update the cursor position after deleting
          amountController.selection = TextSelection.collapsed(
            offset: newCursorPosition,
          );
        }

        // Finally, inform the cubit of the change
        context.read<ReceiveBloc>().add(ReceiveAmountInputChanged(newAmount));
      },
    );
  }
}
