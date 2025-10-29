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
    this.onPastePressed,
  });

  final Function(String) onNumberPressed;
  final Function() onBackspacePressed;
  final Function()? onPastePressed;
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
              color: context.colour.surfaceContainerLow,
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
              color: context.colour.surfaceContainerLow,
            ),
          ),
        ),
      ),
    );
  }

  Widget emptyButton() {
    return const Expanded(child: SizedBox(height: 64));
  }

  Widget pasteButton(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onPastePressed,
        splashFactory: disableFeedback ? NoSplash.splashFactory : null,
        highlightColor: disableFeedback ? Colors.transparent : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: Icon(
              Icons.content_paste,
              color: context.colour.surfaceContainerLow,
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
              if (onPastePressed != null)
                pasteButton(context)
              else if (onlyDigits)
                emptyButton()
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
/// Works with readonly TextFields - always adds/removes from the end
class AmountDialPad extends StatelessWidget {
  const AmountDialPad({
    super.key,
    required this.controller,
    required this.inputCurrencyCode,
    this.disableFeedback = false,
    this.onAmountChanged,
    this.onPaste,
  });

  final TextEditingController controller;
  final String inputCurrencyCode;
  final bool disableFeedback;
  final VoidCallback? onAmountChanged;
  final VoidCallback? onPaste;

  void _handleNumberPressed(String number) {
    final formatter = AmountInputFormatter(inputCurrencyCode);
    final currentText = controller.text;

    // Always append to the end (field is readonly, no cursor position to track)
    final newText = currentText + number;

    final formattedValue = formatter.formatEditUpdate(
      TextEditingValue(text: currentText),
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      ),
    );

    if (formattedValue.text != currentText) {
      controller.value = formattedValue;
      onAmountChanged?.call();
    }
  }

  void _handleBackspacePressed() {
    final formatter = AmountInputFormatter(inputCurrencyCode);
    final currentText = controller.text;

    if (currentText.isEmpty) return;

    // Always remove from the end (field is readonly, no cursor position to track)
    final newText = currentText.substring(0, currentText.length - 1);

    // Apply formatter
    final formattedValue = formatter.formatEditUpdate(
      TextEditingValue(text: currentText),
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      ),
    );

    controller.value = formattedValue;
    onAmountChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Check if decimals are allowed
    final decimalPlaces =
        (inputCurrencyCode == 'sats' || inputCurrencyCode == 'L-sats')
            ? 0
            : (inputCurrencyCode == 'BTC' || inputCurrencyCode == 'L-BTC')
            ? 8
            : 2;
    final onlyDigits = decimalPlaces == 0;

    return DialPad(
      onNumberPressed: _handleNumberPressed,
      onBackspacePressed: _handleBackspacePressed,
      onPastePressed: onPaste,
      disableFeedback: disableFeedback,
      onlyDigits: onlyDigits,
    );
  }
}
