import 'package:flutter/services.dart';

/// Restricts a text field to a valid monetary amount for a given currency —
/// duplicated from `core/widgets/inputs/amount_input_formatter.dart`.
///
/// Decimal places are derived from [inputCurrencyCode]: `0` for sats, `8` for
/// BTC, `2` for fiat. Commas are normalised to dots and over-long fractions
/// are truncated.
class BullAmountInputFormatter extends TextInputFormatter {
  /// Creates a formatter for the given currency code (e.g. `BTC`, `sats`).
  BullAmountInputFormatter(this.inputCurrencyCode);

  /// The currency code that determines the allowed decimal precision.
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
        : 2; // Fiat currencies default to 2 decimals.

    var newText = newValue.text;

    // Convert commas to dots for decimal input.
    if (decimalPlaces > 0) {
      newText = newText.replaceAll(',', '.');
    }

    // If decimalPlaces is 0, reject any input with comma or dot.
    if (decimalPlaces == 0) {
      if (newText.contains(',') || newText.contains('.')) {
        return oldValue;
      }
    } else {
      // Reject if there are multiple decimal points.
      if (newText.indexOf('.') != newText.lastIndexOf('.')) {
        return oldValue;
      }
    }

    final regex = decimalPlaces == 0
        ? RegExp(r'^\d+')
        : RegExp(
            r'^\d+\.?\d{0,'
            '$decimalPlaces'
            '}',
          );
    final match = regex.firstMatch(newText);

    if (match != null) {
      final validText = match.group(0) ?? '';

      if (validText.length < newText.length) {
        return TextEditingValue(
          text: validText,
          selection: TextSelection.collapsed(offset: validText.length),
        );
      } else {
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
