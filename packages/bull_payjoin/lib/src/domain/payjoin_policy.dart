import 'package:primitives/primitives.dart';

/// What the user is doing when a payjoin would apply. Each action has its own
/// switch in [PayjoinPolicy].
enum PayjoinAction {
  /// Paying another user's payjoin request.
  send,

  /// Receiving from another user.
  receive,

  /// Receiving the payout of a Bull Bitcoin exchange buy order.
  buy,

  /// Paying the Bull Bitcoin exchange: sell and bill-payment orders.
  sell,
}

final class PayjoinPolicy {
  static final minimumAllowedAmount = Sats.fromInt(1000);
  static final maximumAllowedAmount = Sats.fromInt(21000000);
  static const minimumSessionLifetime = Duration(minutes: 1);
  static const maximumSessionLifetime = Duration(hours: 24);

  /// Off by default: a user counterparty learns one of our UTXOs.
  final bool sendEnabled;

  /// Off by default and behind the disclaimer: the receiver carries the
  /// economic exposure (fee contribution, UTXO probing).
  final bool receiveEnabled;

  /// On by default: the exchange is already the trusted counterparty to the
  /// trade, so the payjoin reveals nothing it does not know.
  final bool buyEnabled;

  /// On by default, for the same reason as [buyEnabled].
  final bool sellEnabled;

  final Sats minimumAmount;
  final Duration sessionLifetime;

  PayjoinPolicy({
    required this.sendEnabled,
    required this.receiveEnabled,
    required this.buyEnabled,
    required this.sellEnabled,
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
    sendEnabled: false,
    receiveEnabled: false,
    buyEnabled: true,
    sellEnabled: true,
    minimumAmount: Sats.fromInt(10000),
    sessionLifetime: maximumSessionLifetime,
  );

  bool allows(PayjoinAction action) => switch (action) {
    PayjoinAction.send => sendEnabled,
    PayjoinAction.receive => receiveEnabled,
    PayjoinAction.buy => buyEnabled,
    PayjoinAction.sell => sellEnabled,
  };

  /// Whether any switch keeps the payjoin relays in use.
  bool get anyEnabled => PayjoinAction.values.any(allows);

  PayjoinPolicy withAction(PayjoinAction action, {required bool enabled}) =>
      copyWith(
        sendEnabled: action == PayjoinAction.send ? enabled : null,
        receiveEnabled: action == PayjoinAction.receive ? enabled : null,
        buyEnabled: action == PayjoinAction.buy ? enabled : null,
        sellEnabled: action == PayjoinAction.sell ? enabled : null,
      );

  PayjoinPolicy copyWith({
    bool? sendEnabled,
    bool? receiveEnabled,
    bool? buyEnabled,
    bool? sellEnabled,
    Sats? minimumAmount,
    Duration? sessionLifetime,
  }) => PayjoinPolicy(
    sendEnabled: sendEnabled ?? this.sendEnabled,
    receiveEnabled: receiveEnabled ?? this.receiveEnabled,
    buyEnabled: buyEnabled ?? this.buyEnabled,
    sellEnabled: sellEnabled ?? this.sellEnabled,
    minimumAmount: minimumAmount ?? this.minimumAmount,
    sessionLifetime: sessionLifetime ?? this.sessionLifetime,
  );
}

enum PayjoinRelayHealth { available, unavailable }
