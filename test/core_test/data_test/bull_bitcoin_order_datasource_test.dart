import 'package:bb_mobile/core/exchange/data/datasources/bull_bitcoin_order_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiKey =
      'bbak-c668c543468f722d83213a3d80a662b36f22fd53f8f8501a75845c92107c2ad9';
  final dio = Dio(BaseOptions(baseUrl: 'https://api05.bullbitcoin.dev'));
  final datasource = BullBitcoinOrderDatasource(bullBitcoinHttpClient: dio);

  String? createdOrderId;

  test('createBuyOrder returns OrderModel', () async {
    final order = await datasource.createBuyOrder(
      apiKey: apiKey,
      fiatCurrency: FiatCurrency.cad,
      fiatAmount: 10,
      network: Network.lightning,
      isOwner: true,
    );
    createdOrderId = order.orderId;
    expect(order.orderId.isNotEmpty, true);
    expect(order.orderType, 'Buy Bitcoin');
  });
  test('refreshOrderSummary returns OrderModel', () async {
    if (createdOrderId == null) {
      final order = await datasource.createBuyOrder(
        apiKey: apiKey,
        fiatCurrency: FiatCurrency.cad,
        fiatAmount: 10,
        network: Network.lightning,
        isOwner: true,
      );
      createdOrderId = order.orderId;
    }
    final order = await datasource.refreshOrderSummary(
      apiKey: apiKey,
      orderId: createdOrderId!,
    );
    expect(order.orderId, createdOrderId);
    expect(order, isA<OrderModel>());
  });
  test('confirmBuyOrder returns OrderModel', () async {
    if (createdOrderId == null) {
      final order = await datasource.createBuyOrder(
        apiKey: apiKey,
        fiatCurrency: FiatCurrency.cad,
        fiatAmount: 10,
        network: Network.lightning,
        isOwner: true,
      );
      createdOrderId = order.orderId;
    }
    final order = await datasource.confirmBuyOrder(
      apiKey: apiKey,
      orderId: createdOrderId!,
    );
    expect(order.orderId, createdOrderId);
    expect(order.orderType, 'Buy Bitcoin');
  });

  test('getOrderSummary returns OrderModel', () async {
    if (createdOrderId == null) {
      final order = await datasource.createBuyOrder(
        apiKey: apiKey,
        fiatCurrency: FiatCurrency.cad,
        fiatAmount: 10,
        network: Network.lightning,
        isOwner: true,
      );
      createdOrderId = order.orderId;
    }
    final order = await datasource.getOrderSummary(
      apiKey: apiKey,
      orderId: createdOrderId!,
    );
    expect(order.orderId, createdOrderId);
    expect(order.orderType, 'Buy Bitcoin');
  });

  test('listOrderSummaries returns List<OrderModel>', () async {
    final orders = await datasource.listOrderSummaries(apiKey: apiKey);
    expect(orders.isNotEmpty, true);
    for (final order in orders) {
      expect(order.orderId.isNotEmpty, true);
      expect(order, isA<OrderModel>());
    }
  });
}
