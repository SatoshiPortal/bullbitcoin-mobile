class Utils {
  /// A BTC amount: digits, optionally a fraction of at most eight digits.
  ///
  /// Anchored and deliberately narrow. The previous implementation split on
  /// '.' and parsed each part on its own, which accepted several inputs it
  /// should not have:
  ///
  ///  - a sign was lost when the whole part was zero, because `int.parse('-0')`
  ///    is `0`. '-0.9' converted to +90,000,000 sats, and the bounds check only
  ///    rejected `sats < 0`, so the flipped positive value passed;
  ///  - a fraction longer than eight digits was truncated, so a request for
  ///    1.999999999 BTC was paid as 1.99999999 BTC — silently less than asked;
  ///  - '+5' and '1.' parsed, the latter padding an empty fraction to zeros.
  static final RegExp _btcAmount = RegExp(r'^[0-9]+(\.[0-9]{1,8})?$');

  /// Whole BTC above this cannot exist, and multiplying it would overflow
  /// 64-bit arithmetic and could wrap into a value [_checkSatsBounds] accepts.
  static const int _maxWholeBtc = 21000000;

  static int btcToSats(String bitcoins) {
    if (!_btcAmount.hasMatch(bitcoins)) {
      throw FormatException('Invalid BTC amount format');
    }
    final parts = bitcoins.split('.');
    final wholeBtc = int.parse(parts[0]);
    if (wholeBtc > _maxWholeBtc) {
      throw FormatException('BTC amount above the supply cap');
    }
    final fraction = parts.length == 2
        ? int.parse(parts[1].padRight(8, '0'))
        : 0;
    final sats = wholeBtc * 100000000 + fraction;
    _checkSatsBounds(sats);
    return sats;
  }

  /// Converts a BOLT11 millisatoshi amount to satoshis, rounding up.
  ///
  /// The conversion is lossy by construction: BOLT11 denominates in msats and
  /// the pico-BTC multiplier makes sub-satoshi amounts expressible. Rounding
  /// up rather than truncating keeps two properties that callers rely on — a
  /// non-zero invoice never reads as zero (which would look like an amountless
  /// invoice), and the satoshi view never understates what is owed. Use the
  /// msat value itself wherever the amount must be exact.
  static int msatsToSats(int msats) {
    if (msats < 0) {
      throw FormatException('Invalid msats amount: $msats');
    }
    final sats = (msats + 999) ~/ 1000;
    _checkSatsBounds(sats);
    return sats;
  }

  static void _checkSatsBounds(int sats) {
    const twoPointOneQuadrillion = 2_100_000_000_000_000;
    if (sats < 0 || sats > twoPointOneQuadrillion) {
      throw FormatException('Invalid sats amount');
    }
  }

  static String trimLastQuoteOrH(String string) {
    if (string.endsWith("'") || string.endsWith("h")) {
      return string.substring(0, string.length - 1);
    }
    return string;
  }

  static bool isUppercaseAlphanumeric(String string) {
    return RegExp(r'^[A-Z0-9]+$').hasMatch(string);
  }
}
