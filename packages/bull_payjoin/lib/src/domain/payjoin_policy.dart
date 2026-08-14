import 'package:primitives/primitives.dart';

final class PayjoinPolicy {
  static final minimumAllowedAmount = Sats.fromInt(1000);
  static final maximumAllowedAmount = Sats.fromInt(21000000);
  static const minimumSessionLifetime = Duration(minutes: 1);
  static const maximumSessionLifetime = Duration(hours: 24);

  final bool enabled;
  final Sats minimumAmount;
  final Duration sessionLifetime;

  PayjoinPolicy({
    required this.enabled,
    required this.minimumAmount,
    required this.sessionLifetime,
  }) {
    if (minimumAmount.compareTo(minimumAllowedAmount) < 0 ||
        minimumAmount.compareTo(maximumAllowedAmount) > 0) {
      throw ArgumentError.value(
        minimumAmount,
        'minimumAmount',
        'must be between $minimumAllowedAmount and $maximumAllowedAmount sats',
      );
    }
    if (sessionLifetime < minimumSessionLifetime ||
        sessionLifetime > maximumSessionLifetime ||
        sessionLifetime.inMicroseconds % Duration.microsecondsPerSecond != 0) {
      throw ArgumentError.value(
        sessionLifetime,
        'sessionLifetime',
        'must be a whole number of seconds between $minimumSessionLifetime '
            'and $maximumSessionLifetime',
      );
    }
  }

  factory PayjoinPolicy.defaults() => PayjoinPolicy(
    enabled: false,
    minimumAmount: Sats.fromInt(10000),
    sessionLifetime: maximumSessionLifetime,
  );

  PayjoinPolicy copyWith({
    bool? enabled,
    Sats? minimumAmount,
    Duration? sessionLifetime,
  }) => PayjoinPolicy(
    enabled: enabled ?? this.enabled,
    minimumAmount: minimumAmount ?? this.minimumAmount,
    sessionLifetime: sessionLifetime ?? this.sessionLifetime,
  );
}

enum PayjoinRelayHealth { available, unavailable }
