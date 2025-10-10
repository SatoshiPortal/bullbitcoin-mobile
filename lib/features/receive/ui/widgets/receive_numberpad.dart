import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
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
    final formatter = AmountInputFormatter(inputCurrency);

    return DialPad(
      onNumberPressed: (number) {
        final currentValue = amountController.value;
        final selectionStart = currentValue.selection.baseOffset;
        final selectionEnd = currentValue.selection.extentOffset;
        final currentText = currentValue.text;

        // Build new text by inserting/replacing at selection
        final String newText;
        final int newCursorPos;

        if (selectionStart == -1) {
          // Field is not focused, add to end
          newText = currentText + number;
          newCursorPos = newText.length;
        } else if (selectionStart == selectionEnd) {
          // No selection, insert at cursor
          newText =
              currentText.substring(0, selectionStart) +
              number +
              currentText.substring(selectionStart);
          newCursorPos = selectionStart + number.length;
        } else {
          // Replace selection
          newText =
              currentText.substring(0, selectionStart) +
              number +
              currentText.substring(selectionEnd);
          newCursorPos = selectionStart + number.length;
        }

        // Apply formatter (it handles cursor positioning)
        final formattedValue = formatter.formatEditUpdate(
          currentValue,
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newCursorPos),
          ),
        );

        amountController.value = formattedValue;
        context.read<ReceiveBloc>().add(
          ReceiveAmountInputChanged(formattedValue.text),
        );
      },
      onBackspacePressed: () {
        final currentValue = amountController.value;
        final selectionStart = currentValue.selection.baseOffset;
        final selectionEnd = currentValue.selection.extentOffset;
        final currentText = currentValue.text;

        // Build new text by removing at selection
        final String newText;
        final int newCursorPos;

        if (selectionStart == -1) {
          // Field is not focused, remove from end
          newText =
              currentText.isNotEmpty
                  ? currentText.substring(0, currentText.length - 1)
                  : currentText;
          newCursorPos = newText.length;
        } else if (selectionStart == selectionEnd) {
          // No selection, remove before cursor
          if (selectionStart > 0) {
            newText =
                currentText.substring(0, selectionStart - 1) +
                currentText.substring(selectionStart);
            newCursorPos = selectionStart - 1;
          } else {
            newText = currentText;
            newCursorPos = 0;
          }
        } else {
          // Remove selection
          newText =
              currentText.substring(0, selectionStart) +
              currentText.substring(selectionEnd);
          newCursorPos = selectionStart;
        }

        // Apply formatter (it handles cursor positioning)
        final formattedValue = formatter.formatEditUpdate(
          currentValue,
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newCursorPos),
          ),
        );

        amountController.value = formattedValue;
        context.read<ReceiveBloc>().add(
          ReceiveAmountInputChanged(formattedValue.text),
        );
      },
    );
  }
}
