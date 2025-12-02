import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

/// Base DialPad widget for numeric entry (PIN, amount, etc.)
class DialPad extends StatelessWidget {
  const DialPad({
    super.key,
    required this.onNumberPressed,
    required this.onBackspacePressed,
    this.disableFeedback = false,
    this.onlyDigits = false,
  });

  final Function(String) onNumberPressed;
  final Function() onBackspacePressed;
  final bool disableFeedback;
  final bool onlyDigits;

  Widget numPadButton(BuildContext context, String num) {
    return Expanded(
      child: InkWell(
        onTap: () => onNumberPressed(num),
        splashFactory: disableFeedback ? NoSplash.splashFactory : null,
        highlightColor: disableFeedback ? Colors.transparent : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: BBText(
              num,
              style: context.font.headlineMedium?.copyWith(fontSize: 20),
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget backspaceButton(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onBackspacePressed,
        splashFactory: disableFeedback ? NoSplash.splashFactory : null,
        highlightColor: disableFeedback ? Colors.transparent : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              numPadButton(context, '1'),
              numPadButton(context, '2'),
              numPadButton(context, '3'),
            ],
          ),
          Row(
            children: [
              numPadButton(context, '4'),
              numPadButton(context, '5'),
              numPadButton(context, '6'),
            ],
          ),
          Row(
            children: [
              numPadButton(context, '7'),
              numPadButton(context, '8'),
              numPadButton(context, '9'),
            ],
          ),
          Row(
            children: [
              if (onlyDigits)
                const Expanded(child: SizedBox(height: 64))
              else
                numPadButton(context, '.'),
              numPadButton(context, '0'),
              backspaceButton(context),
            ],
          ),
        ],
      ),
    );
  }
}

/// DialPad widget for amount entry with built-in formatting
class AmountDialPad extends StatelessWidget {
  const AmountDialPad({
    super.key,
    required this.controller,
    required this.inputCurrencyCode,
    this.disableFeedback = false,
    this.onAmountChanged,
  });

  final TextEditingController controller;
  final String inputCurrencyCode;
  final bool disableFeedback;
  final VoidCallback? onAmountChanged;

  void _handleNumberPressed(String number) {
    final formatter = AmountInputFormatter(inputCurrencyCode);
    final currentValue = controller.value;
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

    if (formattedValue.text != currentText) {
      controller.value = formattedValue;
      onAmountChanged?.call();
    }
  }

  void _handleBackspacePressed() {
    final formatter = AmountInputFormatter(inputCurrencyCode);
    final currentValue = controller.value;
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

    if (formattedValue.text != currentText) {
      controller.value = formattedValue;
      onAmountChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if decimals are allowed
    final decimalPlaces =
        inputCurrencyCode == 'sats'
            ? 0
            : inputCurrencyCode == 'BTC'
            ? 8
            : 2;
    final onlyDigits = decimalPlaces == 0;

    return DialPad(
      onNumberPressed: _handleNumberPressed,
      onBackspacePressed: _handleBackspacePressed,
      disableFeedback: disableFeedback,
      onlyDigits: onlyDigits,
    );
  }
}
