import 'package:bbx_api/src/bbx_api_client.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/orders/order_stats.dart';

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
}
