import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/btc_network.dart';
import '../domain/entities/dca.dart';
import '../domain/entities/order.dart';
import '../domain/entities/sepa_payment_processor.dart';
import '../domain/exchange_call_result.dart';
import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';
import '../domain/repositories/orders_repository.dart';
import '../domain/unknown_write_journal.dart';

/// Records a write with an unknown outcome in the journal before its result
/// reaches the caller. A journal failure is logged and never changes the
/// write's result.
final class UnknownWriteRecorder {
  final UnknownWriteJournal _journal;

  const UnknownWriteRecorder(this._journal);

  /// Records [draft] when [write] is [WriteOutcomeUnknown], then returns
  /// [write] unchanged.
  Future<ExchangeWrite<T>> afterWrite<T>(
    ExchangeWrite<T> write,
    Future<UnknownWriteDraft> Function() draft,
  ) async {
    if (write is WriteOutcomeUnknown<T>) await record(await draft());
    return write;
  }

  Future<void> record(UnknownWriteDraft draft) async {
    switch (await _journal.record(draft)) {
      case Ok():
        return;
      case Err(:final failure):
        log.severe(
          message:
              'Could not journal an exchange write with an unknown outcome',
          error: failure.logMessage ?? failure,
          trace: StackTrace.current,
        );
    }
  }
}

/// [OrdersRepository] whose confirm, accelerate and DCA writes are journaled
/// when their outcome is unknown. Everything else is passed through.
final class JournalingOrdersRepository implements OrdersRepository {
  final OrdersRepository _orders;
  final UnknownWriteRecorder _recorder;
  final ExchangeEnvironment _environment;
  final Future<int?> Function() _readEpoch;

  const JournalingOrdersRepository(
    this._orders,
    this._recorder, {
    required this._environment,
    required this._readEpoch,
  });

  Future<UnknownWriteDraft> _draft(
    UnknownWriteKind kind,
    Map<String, String> request, {
    String? orderId,
  }) async => UnknownWriteDraft(
    kind: kind,
    environment: _environment,
    sessionEpoch: await _readEpoch(),
    orderId: orderId,
    request: request,
  );

  @override
  Future<ExchangeWrite<BuyOrder>> confirmBuyOrder(String orderId) async =>
      _recorder.afterWrite(
        await _orders.confirmBuyOrder(orderId),
        () => _draft(UnknownWriteKind.buyConfirm, {
          'orderId': orderId,
        }, orderId: orderId),
      );

  /// The Interac answer is a secret: only whether an update was sent is
  /// journaled.
  @override
  Future<ExchangeWrite<WithdrawOrder>> confirmWithdrawOrder(
    String orderId, {
    ({
      String recipientId,
      String email,
      String? securityQuestion,
      String? securityAnswer,
    })?
    interacUpdate,
  }) async => _recorder.afterWrite(
    await _orders.confirmWithdrawOrder(orderId, interacUpdate: interacUpdate),
    () => _draft(UnknownWriteKind.withdrawConfirm, {
      'orderId': orderId,
      'interacUpdate': '${interacUpdate != null}',
    }, orderId: orderId),
  );

  @override
  Future<ExchangeWrite<BuyOrder>> accelerateBuyOrder(String orderId) async =>
      _recorder.afterWrite(
        await _orders.accelerateBuyOrder(orderId),
        () => _draft(UnknownWriteKind.accelerate, {
          'orderId': orderId,
        }, orderId: orderId),
      );

  @override
  Future<ExchangeWrite<Dca>> createDca({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required BtcNetwork network,
    required String address,
  }) async => _recorder.afterWrite(
    await _orders.createDca(
      amount: amount,
      currency: currency,
      frequency: frequency,
      network: network,
      address: address,
    ),
    () => _draft(UnknownWriteKind.dcaCreate, {
      'amount': '$amount',
      'currency': currency.code,
      'frequency': frequency.name,
      'network': network.name,
      'address': address,
    }),
  );

  @override
  Future<ExchangeWrite<BuyOrder>> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required BtcNetwork network,
    required bool isOwner,
    String? payjoinBip21,
  }) => _orders.placeBuyOrder(
    toAddress: toAddress,
    orderAmount: orderAmount,
    currency: currency,
    network: network,
    isOwner: isOwner,
    payjoinBip21: payjoinBip21,
  );

  @override
  Future<ExchangeWrite<SellOrder>> placeSellOrder({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required BtcNetwork network,
    bool usePayjoin = false,
  }) => _orders.placeSellOrder(
    orderAmount: orderAmount,
    currency: currency,
    network: network,
    usePayjoin: usePayjoin,
  );

  @override
  Future<ExchangeWrite<FiatPaymentOrder>> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required BtcNetwork network,
    String? paymentDescription,
    SepaPaymentProcessor? paymentProcessor,
    bool usePayjoin = false,
    String? securityQuestion,
    String? securityAnswer,
  }) => _orders.placePayOrder(
    orderAmount: orderAmount,
    recipientId: recipientId,
    network: network,
    paymentDescription: paymentDescription,
    paymentProcessor: paymentProcessor,
    usePayjoin: usePayjoin,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
  );

  @override
  Future<ExchangeWrite<WithdrawOrder>> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    SepaPaymentProcessor? paymentProcessor,
    String? securityQuestion,
    String? securityAnswer,
  }) => _orders.placeWithdrawalOrder(
    fiatAmount: fiatAmount,
    recipientId: recipientId,
    paymentProcessor: paymentProcessor,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
  );

  @override
  Future<Result<BuyOrder, ExchangeFailure>> refreshBuyOrder(String orderId) =>
      _orders.refreshBuyOrder(orderId);

  @override
  Future<Result<SellOrder, ExchangeFailure>> refreshSellOrder(String orderId) =>
      _orders.refreshSellOrder(orderId);

  @override
  Future<Result<FiatPaymentOrder, ExchangeFailure>> refreshPayOrder(
    String orderId,
  ) => _orders.refreshPayOrder(orderId);

  @override
  Future<Result<Order, ExchangeFailure>> getOrder(String orderId) =>
      _orders.getOrder(orderId);

  @override
  Future<Result<Order?, ExchangeFailure>> getOrderByTxId(String txId) =>
      _orders.getOrderByTxId(txId);

  @override
  Future<Result<List<Order>, ExchangeFailure>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  }) => _orders.getOrders(limit: limit, offset: offset, type: type);
}
