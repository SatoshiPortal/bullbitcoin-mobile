import 'package:bb_mobile/features/limit_orders/data/models/limit_order_model.dart';
import 'package:bb_mobile/features/limit_orders/data/models/limit_order_rate_model.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_draft.dart';
import 'package:dio/dio.dart';

final class LimitOrdersApiException implements Exception {
  final String? code;

  const LimitOrdersApiException({this.code});

  @override
  String toString() => code == null
      ? 'LimitOrdersApiException'
      : 'LimitOrdersApiException($code)';
}

class LimitOrdersApiDatasource {
  final Dio _client;

  const LimitOrdersApiDatasource({required Dio authenticatedApiClient})
    : _client = authenticatedApiClient;

  Future<List<LimitOrderModel>> listActive() async {
    final result = await _request(
      path: '/ak/api-ordertrigger',
      method: 'listLimitOrders',
      params: {
        'paginator': {'page': 1, 'pageSize': 10},
        'sortBy': {'id': 'createdAt', 'sort': 'desc'},
        'filters': {'status': 'ACTIVE'},
      },
    );
    final elements = result['elements'] as List<dynamic>? ?? const [];
    return elements
        .map(
          (element) =>
              LimitOrderModel.fromJson(element as Map<String, dynamic>),
        )
        .toList();
  }

  Future<LimitOrderModel> get(String id) async {
    final result = await _request(
      path: '/ak/api-ordertrigger',
      method: 'getLimitOrder',
      params: {'limitOrderId': id},
    );
    return LimitOrderModel.fromJson(result);
  }

  Future<LimitOrderModel> create(LimitOrderDraft draft) async {
    final result = await _request(
      path: '/ak/api-ordertrigger',
      method: 'addLimitOrder',
      params: {
        'element': {
          'limitPrice': draft.limitPrice.toStringAsFixed(2),
          'fiatAmount': draft.fiatAmount.toStringAsFixed(2),
          'currencyCode': draft.currencyCode,
          'estimatedBtcAmount': draft.estimatedBtcAmount.toStringAsFixed(8),
          'address': draft.address,
        },
      },
    );
    return LimitOrderModel.fromJson(result);
  }

  Future<LimitOrderModel> cancel(String id) async {
    final result = await _request(
      path: '/ak/api-ordertrigger',
      method: 'cancelLimitOrder',
      params: {'limitOrderId': id},
    );
    return LimitOrderModel.fromJson(result);
  }

  Future<List<LimitOrderModel>> cancelAll() async {
    final result = await _request(
      path: '/ak/api-ordertrigger',
      method: 'cancelAllLimitOrders',
      params: const {},
    );
    final elements = result['elements'] as List<dynamic>? ?? const [];
    return elements
        .map(
          (element) =>
              LimitOrderModel.fromJson(element as Map<String, dynamic>),
        )
        .toList();
  }

  Future<LimitOrderRateModel> getRate(String currencyCode) async {
    final result = await _request(
      path: '/public/price',
      method: 'getUserRate',
      params: {
        'element': {'fromCurrency': currencyCode, 'toCurrency': 'BTC'},
      },
    );
    final element = result['element'] as Map<String, dynamic>? ?? result;
    return LimitOrderRateModel.fromJson(element);
  }

  Future<Map<String, dynamic>> _request({
    required String path,
    required String method,
    required Map<String, dynamic> params,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      path,
      data: {'jsonrpc': '2.0', 'id': '0', 'method': method, 'params': params},
    );
    if (response.statusCode != 200) {
      throw const LimitOrdersApiException();
    }
    final body = response.data;
    if (body == null) throw const LimitOrdersApiException();
    final error = body['error'];
    if (error != null) {
      final errorMap = error as Map<String, dynamic>;
      final data = errorMap['data'];
      final code = data is Map<String, dynamic>
          ? data['code'] as String?
          : errorMap['code']?.toString();
      throw LimitOrdersApiException(code: code);
    }
    final result = body['result'];
    if (result is! Map<String, dynamic>) {
      throw const LimitOrdersApiException();
    }
    return result;
  }
}
