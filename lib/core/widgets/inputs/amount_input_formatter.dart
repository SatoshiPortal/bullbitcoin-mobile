import 'package:flutter/services.dart';

class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter(this.inputCurrencyCode);

  final String inputCurrencyCode;

  /// Strip leading zeros from amount text
  /// 0000 -> 0, 00.5 -> 0.5, 0001 -> 1
  static String stripLeadingZeros(String text, int decimalPlaces) {
    if (text.isEmpty || text == '0') {
      return text;
    }

    if (text.startsWith('0') && text.length > 1) {
      // Check if it's "0." followed by decimals (valid for decimal currencies)
      if (decimalPlaces > 0 && text.startsWith('0.')) {
        return text; // Valid: 0.5, 0.123, etc
      }

      // Find first non-zero digit or decimal point
      int firstNonZeroIndex = 0;
      for (int i = 0; i < text.length; i++) {
        if (text[i] != '0') {
          firstNonZeroIndex = i;
          break;
        }
      }

      // If all zeros, keep single 0
      if (firstNonZeroIndex == 0 && text.replaceAll('0', '').isEmpty) {
        return '0';
      } else if (firstNonZeroIndex < text.length &&
          text[firstNonZeroIndex] == '.') {
        // 00.5 -> 0.5
        return '0${text.substring(firstNonZeroIndex)}';
      } else if (firstNonZeroIndex > 0 && firstNonZeroIndex < text.length) {
        // 0001 -> 1, 00123 -> 123
        return text.substring(firstNonZeroIndex);
      }
    }

    return text;
  }

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

    // Strip leading zeros
    newText = stripLeadingZeros(newText, decimalPlaces);

    // Apply regex validation
    final regex =
        decimalPlaces == 0
            ? RegExp(r'^\d*$')
            : RegExp(r'^\d*\.?\d{0,' + '$decimalPlaces' + r'}$');

    if (!regex.hasMatch(newText)) {
      return oldValue;
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
