import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';

class ExchangeOrderRepositoryImpl implements ExchangeOrderRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;

  ExchangeOrderRepositoryImpl({
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
  }) : _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource;

  @override
  Future<Order> getOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get();

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

      return orderModel.toEntity();
    } catch (e) {
      throw Exception('Failed to get order: $e');
    }
  }

  @override
  Future<List<Order>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get();

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

      List<Order> orders =
          orderModels.map((model) => model.toEntity()).toList();

      // this filtering should also be done separately, read from disk not over network
      if (type != null) {
        switch (type) {
          case OrderType.buy:
            orders = orders.whereType<BuyOrder>().toList();
          case OrderType.sell:
            orders = orders.whereType<SellOrder>().toList();
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
      throw Exception('Failed to get orders: $e');
    }
  }

  @override
  Future<BuyOrder> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required Network network,
    required String isOwner,
  }) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get();

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

      final orderModel = await _bullbitcoinApiDatasource.createBuyOrder(
        apiKey: apiKeyModel.key,
        fiatCurrency: currency,
        orderAmount: orderAmount,
        network: network,
        isOwner: isOwner == 'true',
      );

      final order = orderModel.toEntity();

      if (order is! BuyOrder) {
        throw Exception(
          'Expected BuyOrder but received a different order type',
        );
      }

      return order;
    } catch (e) {
      throw Exception('Failed to place buy order: $e');
    }
  }

  @override
  Future<BuyOrder> confirmBuyOrder(String orderId) async {
    try {
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get();

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

      final order = orderModel.toEntity();

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
      final apiKeyModel = await _bullbitcoinApiKeyDatasource.get();

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

      final order = orderModel.toEntity();

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
}
