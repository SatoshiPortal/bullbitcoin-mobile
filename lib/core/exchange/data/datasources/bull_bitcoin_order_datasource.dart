import 'package:bb_mobile/core/exchange/data/models/order_model.dart';
import 'package:dio/dio.dart';

class BullBitcoinOrderDatasource {
  final Dio _http;

  BullBitcoinOrderDatasource({required Dio bullBitcoinHttpClient})
    : _http = bullBitcoinHttpClient;

  Future<OrderModel> createBuyOrder({
    required String apiKey,
    required FiatCurrency fiatCurrency,
    required double fiatAmount,
    required Network network,
    required bool isOwner,
  }) async {
    final resp = await _http.post(
      '/ak/api-orders',
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'createOrderBuy',
        'params': {
          'fiatCurrency': fiatCurrency.apiValue,
          'fiatAmount': fiatAmount,
          'network': network.apiValue,
          'isOwner': isOwner,
        },
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) throw Exception('Failed to create order');
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<OrderModel> confirmBuyOrder({
    required String apiKey,
    required String orderId,
  }) async {
    final resp = await _http.post(
      '/ak/api-orders',
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'confirmOrderSummary',
        'params': {'orderId': orderId},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) throw Exception('Failed to confirm order');
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }

  Future<OrderModel> getOrderSummary({
    required String apiKey,
    required String orderId,
  }) async {
    final resp = await _http.post(
      '/ak/api-orders',
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'getOrderSummary',
        'params': {'orderId': orderId},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) throw Exception('Failed to get order summary');
    return OrderModel.fromJson(
      (resp.data['result']['element'] ?? resp.data['result'])
          as Map<String, dynamic>,
    );
  }

  Future<List<OrderModel>> listOrderSummaries({required String apiKey}) async {
    final resp = await _http.post(
      '/ak/api-orders',
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'listOrderSummaries',
        'params': {},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to list order summaries');
    }
    final elements = resp.data['result']['elements'] as List<dynamic>?;
    if (elements == null) return [];
    return elements
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrderModel> refreshOrderSummary({
    required String apiKey,
    required String orderId,
  }) async {
    final resp = await _http.post(
      '/ak/api-orders',
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'refreshOrderSummary',
        'params': {'orderId': orderId},
      },
      options: Options(headers: {'X-API-Key': apiKey}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to refresh order summary');
    }
    return OrderModel.fromJson(resp.data['result'] as Map<String, dynamic>);
  }
}
