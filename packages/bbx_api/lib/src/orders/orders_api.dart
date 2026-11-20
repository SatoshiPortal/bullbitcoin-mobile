import 'package:bbx_api/src/bbx_api_client.dart';
import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/orders/order_stats.dart';
import 'package:bbx_api/src/orders/order_summary.dart';

/// The `api-orders` endpoint.
class OrdersApi {
  static const endpoint = '/ak/api-orders';

  final BbxApiClient _client;

  OrdersApi(this._client);

  /// The user's trading statistics.
  Future<OrderStatsReport> getOrderStats() async {
    final result = read<Map<String, dynamic>>(
      await _client.call(endpoint, 'getOrderStats'),
      'result',
    );
    return OrderStatsReport.fromJson(
      read<Map<String, dynamic>>(result['element'], 'element'),
    );
  }

  /// The order [orderId]. The server wraps it in `element` or returns it as
  /// the result itself; both are read.
  Future<OrderSummary> getOrderSummary(String orderId) async {
    final result = read<Map<String, dynamic>>(
      await _client.call(
        endpoint,
        'getOrderSummary',
        params: {'orderId': orderId},
      ),
      'result',
    );
    return OrderSummary.fromJson(
      read<Map<String, dynamic>>(result['element'] ?? result, 'element'),
    );
  }

  /// Asks the server to re-check the order [orderId] and returns it.
  Future<OrderSummary> refreshOrderSummary(String orderId) async =>
      OrderSummary.fromJson(
        read<Map<String, dynamic>>(
          await _client.call(
            endpoint,
            'refreshOrderSummary',
            params: {'orderId': orderId},
          ),
          'result',
        ),
      );

  /// One page of the user's orders, newest first. A missing element list is
  /// empty.
  Future<OrderSummaryList> listOrderSummaries({
    int page = 1,
    int pageSize = 50,
  }) async {
    final result = read<Map<String, dynamic>>(
      await _client.call(
        endpoint,
        'listOrderSummaries',
        params: {
          'sortBy': {'id': 'createdAt', 'sort': 'desc'},
          'paginator': {'page': page, 'pageSize': pageSize},
        },
      ),
      'result',
    );
    final elements = result['elements'];
    if (elements == null) return const OrderSummaryList(orders: []);
    final orders = <OrderSummary>[];
    final rejected = <BbxApiFormatException>[];
    for (final element in read<List<dynamic>>(elements, 'elements')) {
      try {
        orders.add(
          OrderSummary.fromJson(
            read<Map<String, dynamic>>(element, 'elements'),
          ),
        );
      } on BbxApiFormatException catch (e) {
        rejected.add(e);
      }
    }
    return OrderSummaryList(orders: orders, rejected: rejected);
  }

  /// The user's buy limits, as the server's JSON object.
  Future<Map<String, dynamic>> getBuyLimits() async =>
      read<Map<String, dynamic>>(
        await _client.call(endpoint, 'getBuyLimits'),
        'result',
      );

  /// The user's sell limits, as the server's JSON object.
  Future<Map<String, dynamic>> getSellLimits() async =>
      read<Map<String, dynamic>>(
        await _client.call(endpoint, 'getSellLimits'),
        'result',
      );
}
