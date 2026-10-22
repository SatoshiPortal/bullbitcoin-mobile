import 'package:bb_mobile/core/exchange/domain/entity/order.dart';

/// How long a payjoin can still settle a buy order's payout.
///
/// The exchange stops negotiating it five minutes after creating the order.
/// The receiver starts first so its URI can be included in that request; one
/// additional minute covers receiver setup, network latency and clock skew.
extension BuyPayjoinWindow on BuyOrder {
  static const duration = Duration(minutes: 6);

  /// Whether a payjoin attached to this order may still settle it at [now].
  ///
  /// Past the window the exchange pays out with an ordinary transaction, even
  /// while it has not reported that outcome yet.
  bool isAwaitingPayjoinAt(DateTime now) =>
      payjoinOutcome.isOngoing && now.isBefore(createdAt.add(duration));
}
