import 'dart:math' as math;

import 'package:bull_ui/src/data_display/bull_number_format.dart';
import 'package:flutter/services.dart';

/// Restricts a text field to a valid monetary amount for a given currency.
///
/// Decimal places are derived from [inputCurrencyCode]: `0` for sats, `8` for
/// BTC, `2` for fiat, unless [maxDecimals] overrides it. Over-long fractions
/// are truncated.
///
/// The field shows the amount the way [BullNumberFormat] writes numbers
/// (`1,234.5`, or `1 234,5` in French), and either `,` or `.` typed is taken
/// as the decimal separator, since the keyboard's decimal key follows the
/// device region rather than the app language. Read the raw amount back with
/// `BullAmountController.amount`.
class BullAmountInputFormatter extends TextInputFormatter {
  /// Creates a formatter for the given currency code (e.g. `BTC`, `sats`).
  BullAmountInputFormatter(this.inputCurrencyCode, {this.maxDecimals});

  /// The currency code that determines the allowed decimal precision.
  final String inputCurrencyCode;

  /// Optional hard cap on decimal places, overriding the value derived from
  /// [inputCurrencyCode]. The custom-fee tile passes 2 here so a sat/vByte
  /// rate can't be typed with more precision than it can store/redisplay —
  /// the BTC-derived default of 8 would let "0.12345678" be entered, snap to
  /// the nearest sat/kwu, then redisplay as "0.12" (typed ≠ stored ≠ shown).
  final int? maxDecimals;

  int get _decimalPlaces =>
      maxDecimals ??
      ((inputCurrencyCode == 'sats' || inputCurrencyCode == 'L-sats')
          ? 0
          : inputCurrencyCode == 'BTC' || inputCurrencyCode == 'L-BTC'
          ? 8
          : 2); // Fiat currencies default to 2 decimals.

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    // A cursor move or selection change: nothing to reformat.
    if (oldText == newText) return newValue;

    // Split the edit into the untouched text on both sides and what was
    // typed or pasted in between. The untouched sides are already formatted,
    // so they read back exactly; only the middle needs interpreting.
    final (prefix, suffix) = _unchangedEnds(oldValue, newValue);
    final removed = oldText.substring(prefix, oldText.length - suffix);
    final inserted = newText.substring(prefix, newText.length - suffix);

    var before = BullNumberFormat.fromInputText(oldText.substring(0, prefix));
    var after = BullNumberFormat.fromInputText(
      oldText.substring(oldText.length - suffix),
    );
    // Deleting a thousands separator would be undone by regrouping, so the
    // key deletes the digit it was aimed at instead: backspace the digit in
    // front of the separator, forward delete the digit behind it. A selected
    // separator deleted on its own is simply put back.
    if (inserted.isEmpty &&
        removed.isNotEmpty &&
        removed.replaceAll(BullNumberFormat.groupSeparator, '').isEmpty &&
        oldValue.selection.isCollapsed) {
      final oldCursor = oldValue.selection.end;
      if (oldCursor == prefix + removed.length && before.isNotEmpty) {
        before = before.substring(0, before.length - 1);
      } else if (oldCursor == prefix && after.isNotEmpty) {
        after = after.substring(1);
      }
    }
    final typed = _rawTyped(inserted);
    final raw = '$before$typed$after';

    final validRaw = _validRawAmount(raw, _decimalPlaces);
    if (validRaw == null) return oldValue;

    final text = BullNumberFormat.toInputText(validRaw);
    final rawCursor = validRaw.length < raw.length
        ? validRaw.length
        : math.min(before.length + typed.length, validRaw.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: _textOffset(text, rawCursor)),
    );
  }

  /// The raw amount [text] is valid as, truncated to [decimalPlaces]; `''`
  /// for an empty field, or `null` to reject the edit.
  static String? _validRawAmount(String text, int decimalPlaces) {
    if (text.isEmpty) return '';
    if (decimalPlaces == 0) {
      // Reject any input with comma or dot.
      if (text.contains(',') || text.contains('.')) return null;
    } else if (text.indexOf('.') != text.lastIndexOf('.')) {
      // Reject if there are multiple decimal points.
      return null;
    }

    final regex = decimalPlaces == 0
        ? RegExp(r'^\d+')
        : RegExp(
            r'^\d+\.?\d{0,'
            '$decimalPlaces'
            '}',
          );
    return regex.firstMatch(text)?.group(0);
  }

  /// How many characters at the start and at the end of the field the edit
  /// left alone, anchored on the cursor so typing next to an identical digit
  /// lands where the user typed.
  static (int, int) _unchangedEnds(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    // Clamped: a platform may hand over a selection past the text it sent.
    final cursor = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, newText.length)
        : newText.length;

    var suffix = newText.length - cursor;
    if (suffix > oldText.length ||
        !oldText.endsWith(newText.substring(cursor))) {
      suffix = 0;
      while (suffix < oldText.length &&
          suffix < newText.length &&
          oldText[oldText.length - 1 - suffix] ==
              newText[newText.length - 1 - suffix]) {
        suffix++;
      }
    }

    final prefixLimit = math.min(
      oldText.length - suffix,
      newText.length - suffix,
    );
    var prefix = 0;
    while (prefix < prefixLimit && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    return (prefix, suffix);
  }

  /// Reads typed or pasted [text] as a raw amount.
  ///
  /// A separator typed on its own is the decimal separator, whichever key the
  /// keyboard has. In pasted text the last separator is the decimal one when
  /// both `,` and `.` appear, repeated separators group thousands, and a
  /// single one followed by exactly three digits groups thousands unless it
  /// is the language's own decimal separator: `1,234` is a thousand in
  /// English and one point two three four in French.
  static String _rawTyped(String text) {
    final compact = text.replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');
    final lastSeparator = compact.lastIndexOf(RegExp('[,.]'));
    if (lastSeparator == -1) return compact;

    final separators = RegExp('[,.]').allMatches(compact).length;
    final mixed = compact.contains(',') && compact.contains('.');
    final pastedThousand =
        separators == 1 &&
        compact.length > 1 &&
        compact[lastSeparator] != BullNumberFormat.decimalSeparator &&
        compact.length - lastSeparator - 1 == 3;
    if ((separators > 1 && !mixed) || pastedThousand) {
      return compact.replaceAll(RegExp('[,.]'), '');
    }
    return '${compact.substring(0, lastSeparator).replaceAll(RegExp('[,.]'), '')}'
        '.${compact.substring(lastSeparator + 1)}';
  }

  /// The offset in the formatted [text] after [rawCount] raw characters.
  static int _textOffset(String text, int rawCount) {
    var seen = 0;
    var offset = 0;
    while (offset < text.length && seen < rawCount) {
      if (text[offset] != BullNumberFormat.groupSeparator) seen++;
      offset++;
    }
    return offset;
  }
}
