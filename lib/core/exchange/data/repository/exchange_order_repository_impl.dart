import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/buy/domain/buy_error.dart';

class ExchangeOrderRepositoryImpl implements ExchangeOrderRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;
  final bool _isTestnet;

  ExchangeOrderRepositoryImpl({
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
    required bool isTestnet,
  }) : _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource,
       _isTestnet = isTestnet;

  @override
  Future<Order> getOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw Exception(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw Exception(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final orderModel = await _bullbitcoinApiDatasource.getOrderSummary(
        apiKey: apiKeyModel.key,
        orderId: orderId,
      );

      return orderModel.toEntity(isTestnet: _isTestnet);
    } catch (e) {
      throw Exception('Failed to get order: $e');
    }
  }

  @override
  Future<Order?> getOrderByTxId(String txId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw Exception(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw Exception(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final orderModels = await _bullbitcoinApiDatasource.listOrderSummaries(
        apiKey: apiKeyModel.key,
      );

      final orderModel = orderModels.firstWhere(
        (model) =>
            model.bitcoinTransactionId == txId ||
            model.liquidTransactionId == txId,
        orElse: () => throw Exception('Order not found for txId: $txId'),
      );

      return orderModel.toEntity(isTestnet: _isTestnet);
    } catch (e) {
      log.severe('Error fetching order by txId: $e');
      return null;
    }
  }

  @override
  Future<List<Order>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        log.info(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
        return [];
      }

      if (!apiKeyModel.isActive) {
        log.info(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
        return [];
      }

      final orderModels = await _bullbitcoinApiDatasource.listOrderSummaries(
        apiKey: apiKeyModel.key,
      );

      List<Order> orders =
          orderModels
              .map((model) => model.toEntity(isTestnet: _isTestnet))
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

      return orders;
    } catch (e) {
      log.severe('Error fetching orders: $e');
      return [];
    }
  }

  @override
  Future<BuyOrder> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required Network network,
    required bool isOwner,
  }) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null || !apiKeyModel.isActive) {
        throw const BuyError.unauthenticated();
      }

      final orderModel = await _bullbitcoinApiDatasource.createBuyOrder(
        apiKey: apiKeyModel.key,
        fiatCurrency: currency,
        orderAmount: orderAmount,
        network: network,
        isOwner: isOwner,
        address: toAddress,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet) as BuyOrder;

      return order;
    } on BullBitcoinApiMinAmountException catch (e) {
      final minAmountBtc = e.minAmount;
      final minAmountSat = minAmountBtc * 1e8; // Convert BTC
      throw BuyError.belowMinAmount(minAmountSat: minAmountSat.toInt());
    } on BullBitcoinApiMaxAmountException catch (e) {
      final maxAmountBtc = e.maxAmount;
      final maxAmountSat = maxAmountBtc * 1e8; // Convert BTC
      throw BuyError.aboveMaxAmount(maxAmountSat: maxAmountSat.toInt());
    } catch (e) {
      throw Exception('Failed to place buy order: $e');
    }
  }

  @override
  Future<BuyOrder> confirmBuyOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw Exception(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw Exception(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final orderModel = await _bullbitcoinApiDatasource.confirmBuyOrder(
        apiKey: apiKeyModel.key,
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet);

      if (order is! BuyOrder) {
        throw Exception(
          'Expected BuyOrder but received a different order type',
        );
      }

      return order;
    } catch (e) {
      throw Exception('Failed to confirm buy order: $e');
    }
  }

  @override
  Future<BuyOrder> refreshBuyOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw Exception(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw Exception(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final orderModel = await _bullbitcoinApiDatasource.refreshOrderSummary(
        apiKey: apiKeyModel.key,
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet);

      if (order is! BuyOrder) {
        throw Exception(
          'Expected BuyOrder but received a different order type',
        );
      }

      return order;
    } catch (e) {
      throw Exception('Failed to refresh buy order: $e');
    }
  }

  @override
  Future<BuyOrder> accelerateBuyOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw Exception(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw Exception(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final orderModel = await _bullbitcoinApiDatasource.dequeueAndPay(
        apiKey: apiKeyModel.key,
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet) as BuyOrder;

      return order;
    } catch (e) {
      throw Exception('Failed to dequeue and pay order: $e');
    }
  }
}
