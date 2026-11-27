import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/btc_network.dart';
import '../entities/dca.dart';
import '../entities/order.dart';
import '../entities/sepa_payment_processor.dart';
import '../exchange_failure.dart';

/// Orders for the selected backend; requests require the matching session.
abstract interface class OrdersRepository {
  /// [payjoinBip21] replaces [toAddress] on the wire when set: the exchange then
  /// pays through payjoin, extracting the payout address from the URI. The two
  /// are mutually exclusive and cannot be swapped after the order exists.
  ///
  /// A create that may have reached the server is [ExchangeWriteOutcomeUnknownFailure] (the
  /// order may exist), never a failure that invites a second create.
  @useResult
  Future<Result<BuyOrder, ExchangeWriteFailure>> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required BtcNetwork network,
    required bool isOwner,
    String? payjoinBip21,
  });

  /// [usePayjoin] asks the exchange to receive the payin through payjoin, which
  /// makes it publish a `bip21URI` on the returned order. Bitcoin on-chain only.
  ///
  /// The buy, sell, pay and withdrawal creates answer a write result: a create
  /// that may have reached the server is [ExchangeWriteOutcomeUnknownFailure] (the order may
  /// exist), never a failure that invites a second create.
  @useResult
  Future<Result<SellOrder, ExchangeWriteFailure>> placeSellOrder({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required BtcNetwork network,
    bool usePayjoin = false,
  });
  @useResult
  Future<Result<FiatPaymentOrder, ExchangeWriteFailure>> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required BtcNetwork network,
    String? paymentDescription,
    SepaPaymentProcessor? paymentProcessor,
    bool usePayjoin = false,
    String? securityQuestion,
    String? securityAnswer,
  });
  @useResult
  Future<Result<WithdrawOrder, ExchangeWriteFailure>> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    SepaPaymentProcessor? paymentProcessor,
    String? securityQuestion,
    String? securityAnswer,
  });

  /// A reply of another order type, or one that can't be mapped, is
  /// [ExchangeWriteOutcomeUnknownFailure]: the order may be confirmed.
  @useResult
  Future<Result<BuyOrder, ExchangeWriteFailure>> confirmBuyOrder(
    String orderId,
  );

  /// An optional update uses the same session as the confirmation. Its
  /// failure leaves the confirmed withdrawal successful.
  @useResult
  Future<Result<WithdrawOrder, ExchangeWriteFailure>> confirmWithdrawOrder(
    String orderId, {
    ({
      String recipientId,
      String email,
      String? securityQuestion,
      String? securityAnswer,
    })?
    interacUpdate,
  });
  @useResult
  Future<Result<BuyOrder, ExchangeFailure>> refreshBuyOrder(String orderId);
  @useResult
  Future<Result<SellOrder, ExchangeFailure>> refreshSellOrder(String orderId);
  @useResult
  Future<Result<FiatPaymentOrder, ExchangeFailure>> refreshPayOrder(
    String orderId,
  );
  @useResult
  Future<Result<BuyOrder, ExchangeWriteFailure>> accelerateBuyOrder(
    String orderId,
  );
  @useResult
  Future<Result<Order, ExchangeFailure>> getOrder(String orderId);

  /// No matching transaction or no stored session returns `Ok(null)`.
  /// Rejected rows make an absent transaction uncertain and return a failure.
  @useResult
  Future<Result<Order?, ExchangeFailure>> getOrderByTxId(String txId);

  /// No stored session returns an empty history, not proof of no pending orders.
  @useResult
  Future<Result<List<Order>, ExchangeFailure>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  });

  /// A create that may have reached the server without a readable answer,
  /// including a created DCA whose reply can't be mapped, is
  /// [ExchangeWriteOutcomeUnknownFailure]: the recurring buy may exist.
  @useResult
  Future<Result<Dca, ExchangeWriteFailure>> createDca({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required BtcNetwork network,
    required String address,
  });
}
