import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:primitives/primitives.dart' show Sats;

/// Restricts a text field to a well-formed monetary amount for a currency.
///
/// Precision is zero for sats, eight for BTC and currency-specific for fiat, unless [maxDecimals] overrides it. Leading zeros and decimal commas are normalized without changing the value. Invalid edits, truncating pastes and bitcoin amounts above 21,000,000 BTC are rejected.
class BullAmountInputFormatter extends TextInputFormatter {
  /// Creates a formatter for the given currency code (e.g. `BTC`, `sats`).
  BullAmountInputFormatter(
    this.inputCurrencyCode, {
    this.maxDecimals,
    this.enforceBitcoinSupply = true,
  });

  /// The currency code that determines the allowed decimal precision.
  final String inputCurrencyCode;

  /// Optional hard cap on decimal places, overriding the value derived from
  /// [inputCurrencyCode]. The custom-fee tile passes 2 here so a sat/vByte
  /// rate can't be typed with more precision than it can store/redisplay —
  /// the BTC-derived default of 8 would let "0.12345678" be entered, snap to
  /// the nearest sat/kwu, then redisplay as "0.12" (typed ≠ stored ≠ shown).
  final int? maxDecimals;

  /// False for rates (for example sat/vByte), which are not bitcoin amounts.
  final bool enforceBitcoinSupply;

  bool get _isSats =>
      inputCurrencyCode == 'sats' || inputCurrencyCode == 'L-sats';

  bool get _isBtc => inputCurrencyCode == 'BTC' || inputCurrencyCode == 'L-BTC';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Leave an IME composition intact; it is validated once committed.
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }

    final decimalPlaces =
        maxDecimals ??
        (_isSats
            ? 0
            : (_isBtc
                  ? 8
                  : NumberFormat.currency(name: inputCurrencyCode)
                            .decimalDigits ??
                        2));
    final original = newValue.text;
    if (original.isEmpty) {
      return const TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final text = decimalPlaces > 0 ? original.replaceAll(',', '.') : original;
    final match = RegExp(r'^(\d*)(?:\.(\d*))?$').firstMatch(text);
    if (match == null || match.end != text.length) return oldValue;

    final whole = match.group(1) ?? '';
    final fraction = match.group(2);
    if (fraction != null && decimalPlaces == 0) return oldValue;
    if ((fraction?.length ?? 0) > decimalPlaces) return oldValue;
    if (whole.isEmpty && fraction == null) return oldValue;

    final stripped = whole.replaceFirst(RegExp(r'^0+'), '');
    final normalizedWhole = stripped.isEmpty ? '0' : stripped;
    final normalized = fraction == null
        ? normalizedWhole
        : '$normalizedWhole.$fraction';

    if (_exceedsSupply(normalizedWhole, fraction)) return oldValue;

    final removed = whole.length - normalizedWhole.length;
    int mapOffset(int offset) =>
        offset < 0 ? offset : (offset - removed).clamp(0, normalized.length);
    return newValue.copyWith(
      text: normalized,
      selection: newValue.selection.copyWith(
        baseOffset: mapOffset(newValue.selection.baseOffset),
        extentOffset: mapOffset(newValue.selection.extentOffset),
      ),
      composing: TextRange.empty,
    );
  }

  bool _exceedsSupply(String whole, String? fraction) {
    if (!enforceBitcoinSupply || (!_isSats && !_isBtc)) return false;
    final wholeValue = BigInt.parse(whole);
    if (_isSats) {
      return wholeValue > Sats.maxBitcoinSupply;
    }
    if (!_isBtc) return false;
    final max = Sats.maxBitcoinSupply ~/ BigInt.from(100000000);
    if (wholeValue > max) return true;
    return wholeValue == max && (fraction ?? '').replaceAll('0', '').isNotEmpty;
  }
}
