import 'package:primitives/primitives.dart';

final class PayjoinPolicy {
  static final minimumAllowedAmount = Sats.fromInt(1000);
  static final maximumAllowedAmount = Sats.fromInt(21000000);
  static const minimumSessionLifetime = Duration(minutes: 1);
  static const maximumSessionLifetime = Duration(hours: 24);

  /// Governs payjoin RECEIVING outside trades (the regular receive flow and
  /// its receiver sessions). Off by default behind the one-time disclaimer:
  /// the receiver carries the economic exposure (fee contribution, UTXO
  /// probing).
  final bool enabled;

  /// Governs payjoin for Bull Bitcoin exchange trades (buy/sell/pay orders)
  /// INDEPENDENTLY of [enabled]: the exchange API is a trusted counterparty
  /// to the trade itself, so trade payjoins are on by default and need no
  /// disclaimer. [enabled] gates only non-trade sessions; this gates only
  /// trade sessions (see PayjoinEngine.isReceiverAllowed).
  final bool tradingEnabled;

  /// Governs payjoin on regular sends (paying a third-party BIP21 request
  /// that offers payjoin), independent of [enabled] and [tradingEnabled].
  /// ON by default and disclaimer-free: the sender's exposure is only an
  /// earlier commitment point — the economic risk of a payjoin sits with
  /// the receiver, which is why [enabled] (receiving) is the opt-in one.
  final bool sendEnabled;
  final Sats minimumAmount;
  final Duration sessionLifetime;

  PayjoinPolicy({
    required this.enabled,
    required this.tradingEnabled,
    required this.sendEnabled,
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
    tradingEnabled: true,
    sendEnabled: true,
    minimumAmount: Sats.fromInt(10000),
    sessionLifetime: maximumSessionLifetime,
  );

  PayjoinPolicy copyWith({
    bool? enabled,
    bool? tradingEnabled,
    bool? sendEnabled,
    Sats? minimumAmount,
    Duration? sessionLifetime,
  }) => PayjoinPolicy(
    enabled: enabled ?? this.enabled,
    tradingEnabled: tradingEnabled ?? this.tradingEnabled,
    sendEnabled: sendEnabled ?? this.sendEnabled,
    minimumAmount: minimumAmount ?? this.minimumAmount,
    sessionLifetime: sessionLifetime ?? this.sessionLifetime,
  );
}

enum PayjoinRelayHealth { available, unavailable }
