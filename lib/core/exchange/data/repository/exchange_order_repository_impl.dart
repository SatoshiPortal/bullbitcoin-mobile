import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/buy_error.dart';
import 'package:bb_mobile/core/exchange/domain/errors/pay_error.dart';
import 'package:bb_mobile/core/exchange/domain/errors/sell_error.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart';

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
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
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
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
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
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
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
    required OrderBitcoinNetwork network,
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
      final minAmountSat = ConvertAmount.btcToSats(minAmountBtc);
      throw BuyError.belowMinAmount(minAmountSat: minAmountSat);
    } on BullBitcoinApiMaxAmountException catch (e) {
      final maxAmountBtc = e.maxAmount;
      final maxAmountSat = ConvertAmount.btcToSats(maxAmountBtc);
      throw BuyError.aboveMaxAmount(maxAmountSat: maxAmountSat);
    } catch (e) {
      throw Exception('Failed to place buy order: $e');
    }
  }

  @override
  Future<SellOrder> placeSellOrder({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
  }) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null || !apiKeyModel.isActive) {
        throw const SellError.unauthenticated();
      }

      final orderModel = await _bullbitcoinApiDatasource.createSellOrder(
        apiKey: apiKeyModel.key,
        fiatCurrency: currency,
        orderAmount: orderAmount,
        network: network,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet) as SellOrder;

      return order;
    } on BullBitcoinApiMinAmountException catch (e) {
      final minAmountBtc = e.minAmount;
      final minAmountSat = ConvertAmount.btcToSats(minAmountBtc);
      throw SellError.belowMinAmount(minAmountSat: minAmountSat);
    } on BullBitcoinApiMaxAmountException catch (e) {
      final maxAmountBtc = e.maxAmount;
      final maxAmountSat = ConvertAmount.btcToSats(maxAmountBtc);
      throw SellError.aboveMaxAmount(maxAmountSat: maxAmountSat);
    } catch (e) {
      throw Exception('Failed to place sell order: $e');
    }
  }

  @override
  Future<FiatPaymentOrder> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required String paymentProcessor,
    required OrderBitcoinNetwork network,
  }) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null || !apiKeyModel.isActive) {
        throw const PayError.unauthenticated();
      }

      final orderModel = await _bullbitcoinApiDatasource.createPayOrder(
        apiKey: apiKeyModel.key,
        orderAmount: orderAmount,
        recipientId: recipientId,
        paymentProcessor: paymentProcessor,
        network: network,
      );

      final order =
          orderModel.toEntity(isTestnet: _isTestnet) as FiatPaymentOrder;

      return order;
    } on BullBitcoinApiMinAmountException catch (e) {
      final minAmountBtc = e.minAmount;
      final minAmountSat = ConvertAmount.btcToSats(minAmountBtc);
      throw PayError.belowMinAmount(minAmountSat: minAmountSat);
    } on BullBitcoinApiMaxAmountException catch (e) {
      final maxAmountBtc = e.maxAmount;
      final maxAmountSat = ConvertAmount.btcToSats(maxAmountBtc);
      throw PayError.aboveMaxAmount(maxAmountSat: maxAmountSat);
    } catch (e) {
      throw Exception('Failed to place pay order: $e');
    }
  }

  @override
  Future<BuyOrder> confirmBuyOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final orderModel = await _bullbitcoinApiDatasource.confirmOrder(
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
  Future<WithdrawOrder> confirmWithdrawOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw const WithdrawError.unauthenticated();
      }

      if (!apiKeyModel.isActive) {
        throw const WithdrawError.unauthenticated();
      }

      final orderModel = await _bullbitcoinApiDatasource.confirmOrder(
        apiKey: apiKeyModel.key,
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet);

      if (order is! WithdrawOrder) {
        throw const WithdrawError.unexpected(
          message: 'Expected WithdrawOrder but received a different order type',
        );
      }

      return order;
    } catch (e) {
      if (e is WithdrawError) {
        rethrow;
      }
      throw const WithdrawError.unexpected(
        message: 'Failed to confirm withdraw order',
      );
    }
  }

  @override
  Future<BuyOrder> refreshBuyOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final orderModel = await _bullbitcoinApiDatasource.refreshOrder(
        apiKey: apiKeyModel.key,
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet);

      if (order is! BuyOrder) {
        throw const BuyError.unexpected(
          message: 'Expected BuyOrder but received a different order type',
        );
      }

      return order;
    } catch (e) {
      throw Exception('Failed to refresh order: $e');
    }
  }

  @override
  Future<SellOrder> refreshSellOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final orderModel = await _bullbitcoinApiDatasource.refreshOrder(
        apiKey: apiKeyModel.key,
        orderId: orderId,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet);

      if (order is! SellOrder) {
        throw const SellError.unexpected(
          message: 'Expected SellOrder but received a different order type',
        );
      }

      return order;
    } catch (e) {
      throw SellError.unexpected(message: 'Failed to refresh sell order: $e');
    }
  }

  @override
  Future<BuyOrder> accelerateBuyOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
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

  @override
  Future<WithdrawOrder> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    required String paymentProcessor,
  }) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get(
        isTestnet: _isTestnet,
      );

      if (apiKeyModel == null || !apiKeyModel.isActive) {
        throw const WithdrawError.unauthenticated();
      }

      final orderModel = await _bullbitcoinApiDatasource.createWithdrawalOrder(
        apiKey: apiKeyModel.key,
        fiatAmount: fiatAmount,
        recipientId: recipientId,
        paymentProcessor: paymentProcessor,
      );

      final order = orderModel.toEntity(isTestnet: _isTestnet) as WithdrawOrder;

      return order;
    } on BullBitcoinApiMinAmountException catch (e) {
      final minAmountBtc = e.minAmount;
      final minAmountSat = ConvertAmount.btcToSats(minAmountBtc);
      throw WithdrawError.belowMinAmount(minAmountSat: minAmountSat);
    } on BullBitcoinApiMaxAmountException catch (e) {
      final maxAmountBtc = e.maxAmount;
      final maxAmountSat = ConvertAmount.btcToSats(maxAmountBtc);
      throw WithdrawError.aboveMaxAmount(maxAmountSat: maxAmountSat);
    } catch (e) {
      throw Exception('Failed to create withdrawal order: $e');
    }
  }
}
