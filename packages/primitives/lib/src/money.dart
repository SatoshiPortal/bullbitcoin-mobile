/// A non-negative amount denominated in satoshis.
final class Sats implements Comparable<Sats> {
  final BigInt value;

  Sats(this.value) {
    if (value.isNegative) {
      throw ArgumentError.value(value, 'value', 'must not be negative');
    }
  }

  factory Sats.fromInt(int value) => Sats(BigInt.from(value));

  static final zero = Sats(BigInt.zero);

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
