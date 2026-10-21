import 'package:bb_mobile/core/exchange/domain/exchange_order_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';

class ExchangeOrderRepositoryImpl implements ExchangeOrderRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final bool _isTestnet;

  ExchangeOrderRepositoryImpl({
    required this._bullbitcoinApiDatasource,
    required this._isTestnet,
  });

  @override
  Future<Order> getOrder(String orderId) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.getOrderSummary(
        orderId: orderId,
      );

      return orderModel.toEntity(isTestnet: _isTestnet);
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to get order: $e');
    }
  }

  @override
  Future<Result<Order?, ExchangeOrderFailure>> getOrderByTxId(
    String txId,
  ) async {
    try {
      final orderModels = await _bullbitcoinApiDatasource.listOrderSummaries();

      // A wallet transaction with no matching order is the normal case, not an
      // error, so it must not be logged as one.
      final orderModel = orderModels.firstWhereOrNull(
        (model) => model.matchesTxId(txId),
      );
      if (orderModel == null) return const Ok(null);

      return Ok(orderModel.toEntity(isTestnet: _isTestnet));
    } on Exception catch (e) {
      final refusal = exchangeAuthenticationException(e);
      if (refusal != null) {
        return refusal.isUnauthenticated
            ? const Ok(null)
            : const Err(ExchangeOrderCredentialFailure());
      }
      log.warning('Exchange order lookup failed: ${e.runtimeType}');
      return const Err(ExchangeOrderLoadFailure());
    }
  }

  @override
  Future<Result<List<Order>, ExchangeOrderFailure>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    try {
      final orderModels = await _bullbitcoinApiDatasource.listOrderSummaries();

      // Preserve the remaining history when one order cannot be mapped.
      List<Order> orders = orderModels
          .map((model) {
            try {
              return model.toEntity(isTestnet: _isTestnet);
            } catch (e, stackTrace) {
              log.severe(
                message: 'Error mapping order ${model.orderId}',
                error: e,
                trace: stackTrace,
              );
              return null;
            }
          })
          .whereType<Order>()
          .toList();

      // this filtering should also be done separately, read from disk not over network
      if (type != null) {
        switch (type) {
          case OrderType.buy:
            orders = orders.whereType<BuyOrder>().toList();
          case OrderType.sell:
            orders = orders.whereType<SellOrder>().toList();
          case OrderType.fiatPayment:
            orders = orders.whereType<FiatPaymentOrder>().toList();
          case OrderType.funding:
            orders = orders.whereType<FundingOrder>().toList();
          case OrderType.withdraw:
            orders = orders.whereType<WithdrawOrder>().toList();
          case OrderType.reward:
            orders = orders.whereType<RewardOrder>().toList();
          case OrderType.refund:
            orders = orders.whereType<RefundOrder>().toList();
          case OrderType.balanceAdjustment:
            orders = orders.whereType<BalanceAdjustmentOrder>().toList();
          case OrderType.sellUsdt:
          case OrderType.unknown:
            // Both map onto GenericOrder, so match on the type itself.
            orders = orders.where((o) => o.orderType == type).toList();
        }
      }

      // Pagination should be provided by the endpoint
      if (offset != null || limit != null) {
        final startIndex = offset ?? 0;
        final endIndex = limit != null ? startIndex + limit : orders.length;

        if (startIndex < orders.length) {
          orders = orders.sublist(startIndex, endIndex.clamp(0, orders.length));
        } else {
          orders = [];
        }
      }

      return Ok(orders);
    } on Exception catch (e) {
      final refusal = exchangeAuthenticationException(e);
      if (refusal != null) {
        return refusal.isUnauthenticated
            ? const Ok([])
            : const Err(ExchangeOrderCredentialFailure());
      }
      log.warning('Exchange order history failed: ${e.runtimeType}');
      return const Err(ExchangeOrderLoadFailure());
    }
  }

  @override
  Future<BuyOrder> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    required bool isOwner,
    String? payjoinBip21,
  }) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.createBuyOrder(
        fiatCurrency: currency,
        orderAmount: orderAmount,
        network: network,
        isOwner: isOwner,
        address: payjoinBip21 == null ? toAddress : null,
        bip21URI: payjoinBip21,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet) as BuyOrder;

      return order;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to place buy order: $e');
    }
  }

  @override
  Future<SellOrder> placeSellOrder({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    bool usePayjoin = false,
  }) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.createSellOrder(
        fiatCurrency: currency,
        orderAmount: orderAmount,
        network: network,
        usePayjoin: usePayjoin,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet) as SellOrder;

      return order;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to place sell order: $e');
    }
  }

  @override
  Future<FiatPaymentOrder> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required OrderBitcoinNetwork network,
    String? paymentDescription,
    bool usePayjoin = false,
  }) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.createPayOrder(
        orderAmount: orderAmount,
        recipientId: recipientId,
        network: network,
        paymentDescription: paymentDescription,
        usePayjoin: usePayjoin,
      );

      final order =
          orderModel.toEntity(isTestnet: _isTestnet) as FiatPaymentOrder;

      return order;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      // Keep the original trace: see refreshPayOrder.
      Error.throwWithStackTrace(Exception('Failed to place pay order: $e'), st);
    }
  }

  @override
  Future<BuyOrder> confirmBuyOrder(String orderId) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.confirmOrder(
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet);

      if (order is! BuyOrder) {
        throw UnexpectedOrderTypeException('BuyOrder');
      }

      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to confirm buy order: $e');
    }
  }

  @override
  Future<WithdrawOrder> confirmWithdrawOrder(String orderId) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.confirmOrder(
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet);

      if (order is! WithdrawOrder) {
        throw UnexpectedOrderTypeException('WithdrawOrder');
      }

      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      // Keep the original trace: the use-case logs the trace it catches, so
      // wrapping without it would point every report at this line instead of
      // at the call that actually failed.
      Error.throwWithStackTrace(
        Exception('Failed to confirm withdraw order: $e'),
        st,
      );
    }
  }

  @override
  Future<BuyOrder> refreshBuyOrder(String orderId) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.refreshOrder(
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet);

      if (order is! BuyOrder) {
        throw UnexpectedOrderTypeException('BuyOrder');
      }

      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to refresh order: $e');
    }
  }

  @override
  Future<SellOrder> refreshSellOrder(String orderId) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.refreshOrder(
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet);

      if (order is! SellOrder) {
        throw Exception(
          'Expected SellOrder but received a different order type',
        );
      }

      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to refresh sell order: $e');
    }
  }

  @override
  Future<FiatPaymentOrder> refreshPayOrder(String orderId) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.refreshOrder(
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet);

      if (order is! FiatPaymentOrder) {
        throw UnexpectedOrderTypeException('FiatPaymentOrder');
      }

      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      // Keep the original trace: the use-case logs the trace it catches, so
      // wrapping without it would point every report at this line instead of
      // at the call that actually failed.
      Error.throwWithStackTrace(
        Exception('Failed to refresh pay order: $e'),
        st,
      );
    }
  }

  @override
  Future<BuyOrder> accelerateBuyOrder(String orderId) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.dequeueAndPay(
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet) as BuyOrder;

      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to dequeue and pay order: $e');
    }
  }

  @override
  Future<WithdrawOrder> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    SepaPaymentProcessor? paymentProcessor,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    try {
      final orderModel = await _bullbitcoinApiDatasource.createWithdrawalOrder(
        fiatAmount: fiatAmount,
        recipientId: recipientId,
        paymentProcessor: paymentProcessor,
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet) as WithdrawOrder;

      return order;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on BullBitcoinApiConfidentialSepaNotActivatedException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      // Keep the original trace: see confirmWithdrawOrder. The error itself
      // is dropped because the request carries the Interac security answer.
      Error.throwWithStackTrace(
        Exception('Failed to create withdrawal order'),
        st,
      );
    }
  }

  @override
  Future<Dca> createDca({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required DcaNetwork network,
    required String address,
  }) async {
    try {
      final dcaModel = await _bullbitcoinApiDatasource.createDca(
        amount: amount,
        currency: currency,
        frequency: frequency,
        network: network,
        address: address,
      );

      return dcaModel.toEntity();
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to create DCA: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getBuyLimits() async {
    try {
      return await _bullbitcoinApiDatasource.getBuyLimits();
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to get buy limits: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getSellLimits() async {
    try {
      return await _bullbitcoinApiDatasource.getSellLimits();
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to get sell limits: $e');
    }
  }
}
