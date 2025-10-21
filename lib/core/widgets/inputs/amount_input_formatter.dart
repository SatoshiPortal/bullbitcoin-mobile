import 'package:flutter/services.dart';

class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter(this.inputCurrencyCode);

  final String inputCurrencyCode;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final decimalPlaces =
        (inputCurrencyCode == 'sats' || inputCurrencyCode == 'L-sats')
            ? 0
            : inputCurrencyCode == 'BTC' || inputCurrencyCode == 'L-BTC'
            ? 8
            : 2; // Fiat currencies default to 2 decimals, can be adjusted if needed with a map

    var newText = newValue.text;

    // Convert commas to dots for decimal input
    if (decimalPlaces > 0) {
      newText = newText.replaceAll(',', '.');
    }

    // If decimalPlaces is 0, reject any input with comma or dot
    if (decimalPlaces == 0) {
      if (newText.contains(',') || newText.contains('.')) {
        return oldValue;
      }
    } else {
      // Reject if there are multiple decimal points
      if (newText.indexOf('.') != newText.lastIndexOf('.')) {
        return oldValue;
      }
    }

    // Apply regex validation - only truncate if necessary, don't manipulate cursor aggressively
    final regex =
        decimalPlaces == 0
            ? RegExp(r'^\d+')
            : RegExp(r'^\d+\.?\d{0,' + '$decimalPlaces' + '}');
    final match = regex.firstMatch(newText);

    if (match != null) {
      final validText = match.group(0) ?? '';

      // Only truncate if the text is longer than what's allowed
      if (validText.length < newText.length) {
        // Text was truncated, move cursor to end of valid text
        return TextEditingValue(
          text: validText,
          selection: TextSelection.collapsed(offset: validText.length),
        );
      } else {
        // Text is valid, preserve the original cursor position
        return TextEditingValue(text: validText, selection: newValue.selection);
      }
    } else if (newText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    } else {
      return oldValue;
    }
  }
}
