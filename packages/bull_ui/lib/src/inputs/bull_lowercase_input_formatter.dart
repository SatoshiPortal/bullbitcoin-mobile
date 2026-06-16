import 'package:flutter/services.dart';

/// Lowercases every character a user types — duplicated from
/// `core/widgets/inputs/lowercase_input_formatter.dart`.
class BullLowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}
