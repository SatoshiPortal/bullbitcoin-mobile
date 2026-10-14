import 'package:bull_ui/src/data_display/bull_number_format.dart';
import 'package:flutter/widgets.dart';

/// A controller for an amount field formatted by a localized
/// `BullAmountInputFormatter`.
///
/// The field shows `1,234.5` (or `1 234,5` in French); [amount] reads and
/// writes the raw `1234.5` that blocs and parsing work with. Use [amount]
/// rather than [text] for anything other than display.
///
/// The raw amount is kept alongside the text rather than derived from it on
/// demand, so it stays right when the language changes under a live field;
/// the text is then rewritten with the new separators.
class BullAmountController extends TextEditingController {
  /// Creates a controller showing the raw [amount].
  BullAmountController({String amount = ''})
    : _amount = amount,
      super(text: BullNumberFormat.toInputText(amount)) {
    addListener(_syncAmount);
    BullNumberFormat.languageChanges.addListener(_rewrite);
  }

  String _amount;

  /// The amount without formatting, e.g. `1234.5`; empty when the field is.
  String get amount => _amount;

  /// Shows the raw [amount] formatted, with the cursor at the end.
  set amount(String amount) {
    _amount = amount;
    _show(BullNumberFormat.toInputText(amount));
  }

  void _syncAmount() => _amount = BullNumberFormat.fromInputText(text);

  void _rewrite() {
    final rewritten = BullNumberFormat.toInputText(_amount);
    if (rewritten != text) _show(rewritten);
  }

  void _show(String text) {
    value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    BullNumberFormat.languageChanges.removeListener(_rewrite);
    super.dispose();
  }
}
