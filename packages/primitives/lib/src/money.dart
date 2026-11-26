import 'bitcoin_unit.dart';

/// A non-negative amount denominated in satoshis.
final class Sats implements Comparable<Sats> {
  final BigInt value;

  static final maxBitcoinSupply = BigInt.from(2100000000000000);
  static final zero = Sats(BigInt.zero);

  Sats(this.value) {
    if (value.isNegative) {
      throw ArgumentError.value(value, 'value', 'must not be negative');
    }
  }

  factory Sats.fromInt(int value) => Sats(BigInt.from(value));

  /// Parses an editable bitcoin amount without floating-point conversion.
  static Sats? tryParseBitcoin(String text, BitcoinUnit unit) {
    final BigInt? amount;
    if (unit == BitcoinUnit.sats) {
      final match = RegExp(r'^\d+$').firstMatch(text);
      if (match == null || match.end != text.length) return null;
      amount = BigInt.tryParse(text);
    } else {
      final match = RegExp(r'^(\d+)(?:\.(\d{1,8}))?$').firstMatch(text);
      if (match == null || match.end != text.length) return null;
      final whole = match.group(1);
      if (whole == null) return null;
      final fraction = match.group(2) ?? '';
      amount =
          BigInt.parse(whole) * BigInt.from(100000000) +
          BigInt.parse(fraction.padRight(8, '0'));
    }
    return amount == null || amount > maxBitcoinSupply ? null : Sats(amount);
  }

  /// Converts a normalized decimal fiat edit at its quoted rate, rounding half a satoshi up. Decimal ratios avoid a binary floating-point intermediate at the rounding boundary.
  static Sats? tryFromFiat(String text, double fiatPerBitcoin) {
    if (!fiatPerBitcoin.isFinite || fiatPerBitcoin <= 0) return null;
    final amount = _decimalRatio(text);
    final rate = _decimalRatio(fiatPerBitcoin.toString(), exponent: true);
    if (amount == null || rate == null) return null;
    final (amountNumerator, amountDenominator) = amount;
    final (rateNumerator, rateDenominator) = rate;
    final numerator =
        amountNumerator * rateDenominator * BigInt.from(100000000);
    final denominator = amountDenominator * rateNumerator;
    final two = BigInt.two;
    final sats = (numerator * two + denominator) ~/ (denominator * two);
    return Sats(sats);
  }

  /// Formats the fiat equivalent with decimal half-up rounding, without a binary floating-point intermediate.
  String? toFiatText(double fiatPerBitcoin, {required int decimals}) {
    if (decimals < 0) throw ArgumentError.value(decimals, 'decimals');
    if (!fiatPerBitcoin.isFinite || fiatPerBitcoin <= 0) return null;
    final rate = _decimalRatio(fiatPerBitcoin.toString(), exponent: true);
    if (rate == null) return null;
    final (numerator, denominator) = rate;
    final scaled = value * numerator * BigInt.from(10).pow(decimals);
    final divisor = denominator * BigInt.from(100000000);
    final rounded = (scaled * BigInt.two + divisor) ~/ (divisor * BigInt.two);
    if (decimals == 0) return rounded.toString();
    final digits = rounded.toString().padLeft(decimals + 1, '0');
    return '${digits.substring(0, digits.length - decimals)}.${digits.substring(digits.length - decimals)}';
  }

  static (BigInt, BigInt)? _decimalRatio(String text, {bool exponent = false}) {
    final pattern = exponent
        ? RegExp(r'^(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$')
        : RegExp(r'^(\d+)(?:\.(\d+))?$');
    final match = pattern.firstMatch(text);
    if (match == null || match.end != text.length) return null;
    final whole = match.group(1);
    if (whole == null) return null;
    final fraction = match.group(2) ?? '';
    final power = exponent ? int.parse(match.group(3) ?? '0') : 0;
    final digits = BigInt.parse('$whole$fraction');
    final scale = fraction.length - power;
    return scale < 0
        ? (digits * BigInt.from(10).pow(-scale), BigInt.one)
        : (digits, BigInt.from(10).pow(scale));
  }

  String toBitcoinText(BitcoinUnit unit) {
    if (unit == BitcoinUnit.sats) return value.toString();
    final digits = value.toString().padLeft(9, '0');
    final whole = digits.substring(0, digits.length - 8);
    final fraction = digits
        .substring(digits.length - 8)
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? whole : '$whole.$fraction';
  }

  @override
  int compareTo(Sats other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is Sats && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

/// A positive fee rate denominated in satoshis per virtual byte.
final class FeeRate {
  final double satsPerVbyte;

  FeeRate(this.satsPerVbyte) {
    if (!satsPerVbyte.isFinite || satsPerVbyte <= 0) {
      throw ArgumentError.value(
        satsPerVbyte,
        'satsPerVbyte',
        'must be finite and greater than zero',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FeeRate && satsPerVbyte == other.satsPerVbyte;

  @override
  int get hashCode => satsPerVbyte.hashCode;

  @override
  String toString() => '$satsPerVbyte sat/vB';
}
