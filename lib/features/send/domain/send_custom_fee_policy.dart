enum SendFeeInputMode { rate, total }

enum SendFeeInputError {
  incomplete,
  invalid,
  belowMinimum,
  outOfRange,
  sizeUnavailable,
}

/// Exact validation and display facts; applying a fee remains the screen owner's
/// responsibility. A rate stays relative and an entered total stays absolute.
final class SendFeeEvaluation {
  const SendFeeEvaluation({
    required this.minimumRateSatPerKwu,
    this.error,
    this.relativeSatPerKwu,
    this.absoluteSats,
    this.estimatedSats,
    this.minimumTotalSats,
    this.effectiveRate,
    this.rateWasAdjusted = false,
    this.effectiveRateIsApproximate = false,
    this.warnSubOne = false,
  });

  final int minimumRateSatPerKwu;
  final SendFeeInputError? error;
  final int? relativeSatPerKwu;
  final int? absoluteSats;
  final BigInt? estimatedSats;
  final BigInt? minimumTotalSats;
  final String? effectiveRate;
  final bool rateWasAdjusted;
  final bool effectiveRateIsApproximate;
  final bool warnSubOne;
  bool get isValid => error == null;
  String get minimumRate => SendCustomFeePolicy._decimal(
    BigInt.from(minimumRateSatPerKwu),
    BigInt.from(250),
  );
}

/// Native rates use integer sat/kwu (250 per sat/vB). All comparisons and
/// rounding stay integer-exact before checking native integer representability.
final class SendCustomFeePolicy {
  const SendCustomFeePolicy();

  SendFeeEvaluation evaluate({
    required String text,
    required SendFeeInputMode mode,
    required int minRelaySatPerKwu,
    int? vsize,
  }) {
    final floor = minRelaySatPerKwu < 25 ? 25 : minRelaySatPerKwu;
    final size = vsize != null && vsize > 0 ? BigInt.from(vsize) : null;
    final minTotal = size == null
        ? null
        : _ceil(BigInt.from(floor) * size, BigInt.from(250));
    SendFeeEvaluation fail(SendFeeInputError error) => SendFeeEvaluation(
      minimumRateSatPerKwu: floor,
      minimumTotalSats: minTotal,
      error: error,
    );
    final raw = text.trim();
    if (raw.isEmpty || raw == '.' || RegExp(r'^\d+\.$').hasMatch(raw)) {
      return fail(SendFeeInputError.incomplete);
    }
    if (mode == SendFeeInputMode.total) {
      if (!RegExp(r'^\d+$').hasMatch(raw)) {
        return fail(SendFeeInputError.invalid);
      }
      final sats = BigInt.parse(raw);
      final native = _nativeInt(sats);
      if (native == null) {
        return fail(SendFeeInputError.outOfRange);
      }
      if (size == null || minTotal == null) {
        return fail(SendFeeInputError.sizeUnavailable);
      }
      if (sats < minTotal) {
        return fail(SendFeeInputError.belowMinimum);
      }
      return SendFeeEvaluation(
        minimumRateSatPerKwu: floor,
        minimumTotalSats: minTotal,
        absoluteSats: native,
        estimatedSats: sats,
        effectiveRate: _decimal(sats, size),
        effectiveRateIsApproximate:
            (sats * BigInt.from(1000)) % size != BigInt.zero,
        warnSubOne: sats < size,
      );
    }
    if (!RegExp(r'^(?:\d+(?:\.\d+)?|\.\d+)$').hasMatch(raw)) {
      return fail(SendFeeInputError.invalid);
    }
    final parts = raw.split('.');
    final places = parts.length == 1 ? 0 : parts.last.length;
    final denominator = BigInt.from(10).pow(places);
    final numerator = BigInt.parse(parts.join());
    final scaled = numerator * BigInt.from(250);
    final kwu =
        (scaled * BigInt.two + denominator) ~/ (denominator * BigInt.two);
    final native = _nativeInt(kwu);
    if (native == null) {
      return fail(SendFeeInputError.outOfRange);
    }
    if (native < floor) {
      return fail(SendFeeInputError.belowMinimum);
    }
    return SendFeeEvaluation(
      minimumRateSatPerKwu: floor,
      minimumTotalSats: minTotal,
      relativeSatPerKwu: native,
      estimatedSats: size == null ? null : _ceil(kwu * size, BigInt.from(250)),
      effectiveRate: _decimal(kwu, BigInt.from(250)),
      rateWasAdjusted: kwu * denominator != scaled,
      warnSubOne: native < 250,
    );
  }

  static int? _nativeInt(BigInt value) {
    final converted = value.toInt();
    return BigInt.from(converted) == value ? converted : null;
  }

  static BigInt _ceil(BigInt numerator, BigInt denominator) =>
      (numerator + denominator - BigInt.one) ~/ denominator;

  static String _decimal(BigInt numerator, BigInt denominator) {
    final scale = BigInt.from(1000);
    final rounded =
        (numerator * scale * BigInt.two + denominator) ~/
        (denominator * BigInt.two);
    final whole = rounded ~/ scale;
    final fraction = (rounded % scale)
        .toString()
        .padLeft(3, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole.$fraction';
  }
}
