/// Exact conversion between editable Bitcoin amount strings and satoshis.
abstract final class BullBitcoinAmountText {
  /// Returns null for incomplete or invalid text. Empty text is handled by the
  /// caller so that it remains distinct from zero.
  static BigInt? parse(String text, String unit) {
    if (unit == 'sats') {
      if (!RegExp(r'^\d+$').hasMatch(text)) return null;
      return BigInt.tryParse(text);
    }
    if (unit != 'BTC' || !RegExp(r'^\d+(\.\d{1,8})?$').hasMatch(text)) {
      return null;
    }
    final parts = text.split('.');
    final whole = BigInt.tryParse(parts[0]);
    if (whole == null) return null;
    final fraction = parts.length == 2 ? parts[1].padRight(8, '0') : '0';
    return whole * BigInt.from(100000000) + BigInt.parse(fraction);
  }

  static String format(BigInt sats, String unit) {
    if (sats.isNegative) throw ArgumentError.value(sats, 'sats');
    if (unit == 'sats') return sats.toString();
    if (unit != 'BTC') throw ArgumentError.value(unit, 'unit');
    final digits = sats.toString().padLeft(9, '0');
    final whole = digits.substring(0, digits.length - 8);
    final fraction = digits
        .substring(digits.length - 8)
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? whole : '$whole.$fraction';
  }
}
