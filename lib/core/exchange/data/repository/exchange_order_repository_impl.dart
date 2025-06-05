import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';

class ExchangeOrderRepositoryImpl implements ExchangeOrderRepository {
  // ignore: unused_field
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  // ignore: unused_field
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;

  ExchangeOrderRepositoryImpl({
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
  }) : _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource;

  @override
  Future<Order> getOrder(String orderId) {
    // TODO: implement getOrder
    throw UnimplementedError();
  }

  @override
  Future<List<Order>> getOrders({int? limit, int? offset, OrderType? type}) {
    // TODO: implement getOrders
    throw UnimplementedError();
  }

  @override
  Future<BuyOrder> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required Network network,
    required String isOwner,
  }) {
    // TODO: implement placeBuyOrder
    throw UnimplementedError();
  }
}
