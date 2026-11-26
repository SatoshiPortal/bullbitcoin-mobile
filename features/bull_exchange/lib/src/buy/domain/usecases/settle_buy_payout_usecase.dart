import 'dart:async';

import 'package:exchange/exchange.dart';

/// The wallet effects of a settled buy payout: a completed order writes
/// its exchange labels, and the payout wallet syncs.
class SettleBuyPayoutUsecase {
  final Future<void> Function(List<Order> orders) _labelOrders;
  final Future<void> Function(String walletId) _pollWallet;

  const SettleBuyPayoutUsecase(this._labelOrders, this._pollWallet);

  Future<void> execute(BuyOrder order, String? walletId) async {
    // Only an order that completed may write the privileged exchange
    // labels (#2624).
    if (order.orderStatus == OrderStatus.completed) {
      await _labelOrders([order]);
    }
    if (walletId != null) unawaited(_pollWallet(walletId));
  }
}
