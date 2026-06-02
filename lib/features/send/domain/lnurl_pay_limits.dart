class LnurlPayLimits {
  const LnurlPayLimits({
    required this.minSendableSat,
    required this.maxSendableSat,
  }) : assert(minSendableSat >= 0),
       assert(maxSendableSat >= 0);

  factory LnurlPayLimits.fromMsats({
    required int minSendableMsat,
    required int maxSendableMsat,
  }) {
    final minSat = (minSendableMsat + 999) ~/ 1000;
    final maxSat = maxSendableMsat ~/ 1000;

    if (minSat > maxSat) {
      throw const LnurlPayLimitsInvalidException(
        'Unsupported sub-sat LNURL range',
      );
    }

    return LnurlPayLimits(minSendableSat: minSat, maxSendableSat: maxSat);
  }

  final int minSendableSat;
  final int maxSendableSat;

  bool get isFixedAmount => minSendableSat == maxSendableSat;
}

class LnurlPayLimitsException implements Exception {
  const LnurlPayLimitsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LnurlPayLimitsInvalidException extends LnurlPayLimitsException {
  const LnurlPayLimitsInvalidException(super.message);
}
