import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'entities/dca.dart';
import 'entities/order.dart';
import 'entities/sepa_payment_processor.dart';
import 'exchange_failure.dart';

/// Orders for the selected backend; requests require the matching session.
abstract interface class ExchangeOrders {
  /// [payjoinBip21] replaces [toAddress] on the wire when set: the exchange then
  /// pays through payjoin, extracting the payout address from the URI. The two
  /// are mutually exclusive and cannot be swapped after the order exists.
  @useResult
  Future<Result<BuyOrder, ExchangeFailure>> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    required bool isOwner,
    String? payjoinBip21,
  });

  /// [usePayjoin] asks the exchange to receive the payin through payjoin, which
  /// makes it publish a `bip21URI` on the returned order. Bitcoin on-chain only.
  @useResult
  Future<Result<SellOrder, ExchangeFailure>> placeSellOrder({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    bool usePayjoin = false,
  });
  @useResult
  Future<Result<FiatPaymentOrder, ExchangeFailure>> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required OrderBitcoinNetwork network,
    String? paymentDescription,
    SepaPaymentProcessor? paymentProcessor,
    bool usePayjoin = false,
  });
  @useResult
  Future<Result<WithdrawOrder, ExchangeFailure>> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    SepaPaymentProcessor? paymentProcessor,
    String? securityQuestion,
    String? securityAnswer,
  });
  @useResult
  Future<Result<BuyOrder, ExchangeFailure>> confirmBuyOrder(String orderId);
  @useResult
  Future<Result<WithdrawOrder, ExchangeFailure>> confirmWithdrawOrder(
    String orderId,
  );
  @useResult
  Future<Result<BuyOrder, ExchangeFailure>> refreshBuyOrder(String orderId);
  @useResult
  Future<Result<SellOrder, ExchangeFailure>> refreshSellOrder(String orderId);
  @useResult
  Future<Result<FiatPaymentOrder, ExchangeFailure>> refreshPayOrder(
    String orderId,
  );
  @useResult
  Future<Result<BuyOrder, ExchangeFailure>> accelerateBuyOrder(String orderId);
  @useResult
  Future<Result<Order, ExchangeFailure>> getOrder(String orderId);

  /// No matching transaction or no stored session returns `Ok(null)`.
  @useResult
  Future<Result<Order?, ExchangeFailure>> getOrderByTxId(String txId);

  /// No stored session returns an empty history, not proof of no pending orders.
  @useResult
  Future<Result<List<Order>, ExchangeFailure>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  });
  @useResult
  Future<Result<Dca, ExchangeFailure>> createDca({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required DcaNetwork network,
    required String address,
  });
}
