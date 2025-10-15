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
        inputCurrencyCode == 'sats'
            ? 0
            : inputCurrencyCode == 'BTC'
            ? 8
            : 2; // Fiat currencies default to 2 decimals, can be adjusted if needed with a map

    var newText = newValue.text;

    // If decimalPlaces is 0, reject any input with comma or dot
    if (decimalPlaces == 0) {
      if (newText.contains(',') || newText.contains('.')) {
        return oldValue;
      }
    } else {
      newText = newText.replaceAll(',', '.');

      // Reject if there are multiple decimal points
      if (newText.indexOf('.') != newText.lastIndexOf('.')) {
        return oldValue;
      }
    }

    // Track length before transformations
    final lengthBeforeTransformations = newText.length;

    // Remove leading zeros except for "0." pattern
    if (newText.length > 1) {
      if (newText.startsWith('0') && !newText.startsWith('0.')) {
        // Remove all leading zeros
        newText = newText.replaceFirst(RegExp('^0+'), '');
        // If everything was zeros, keep one zero
        if (newText.isEmpty) {
          newText = '0';
        }
      }
    }

    final lengthAfterLeadingZeroRemoval = newText.length;
    final charsRemovedByLeadingZeroLogic =
        lengthBeforeTransformations - lengthAfterLeadingZeroRemoval;

    final regex =
        decimalPlaces == 0
            ? RegExp(r'^\d+')
            : RegExp(r'^\d+\.?\d{0,' + '$decimalPlaces' + '}');
    final match = regex.firstMatch(newText);

    if (match != null) {
      final validText = match.group(0) ?? '';
      final charsRemovedByRegex = newText.length - validText.length;
      var newOffset = newValue.selection.baseOffset;

      // If characters were removed (by leading zero logic or regex truncation)
      if (charsRemovedByLeadingZeroLogic > 0) {
        // Leading zeros removed: keep cursor at original position
        newOffset = oldValue.selection.baseOffset.clamp(0, validText.length);
      } else if (charsRemovedByRegex > 0) {
        // Text truncated by regex (invalid chars or excess decimals): move to end
        newOffset = validText.length;
      } else if (oldValue.selection.baseOffset == -1) {
        // Field was unfocused, preserve the new offset from the caller (dial pad)
        newOffset = newValue.selection.baseOffset.clamp(0, validText.length);
      } else {
        // Normal case: adjust cursor by the text length difference
        final lengthDifference = validText.length - oldValue.text.length;
        newOffset = (oldValue.selection.baseOffset + lengthDifference).clamp(
          0,
          validText.length,
        );
      }

      return TextEditingValue(
        text: validText,
        selection: TextSelection.collapsed(
          offset: newOffset.clamp(0, validText.length),
        ),
      );
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
