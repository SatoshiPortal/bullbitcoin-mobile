import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/orders/orders_api.dart';
import 'package:dio/dio.dart';

/// JSON-RPC 2.0 over the Bull Bitcoin API.
///
/// The [Dio] client is configured by the caller: base URL, timeouts and
/// authentication. A [DioException], including a refusal raised by the
/// caller's own interceptors, is rethrown unchanged.
class BbxApiClient {
  final Dio _http;

  BbxApiClient(this._http);

  late final OrdersApi orders = OrdersApi(this);

  /// Calls [method] on [endpoint] and returns the JSON-RPC `result`.
  ///
  /// Throws a [BbxApiException] for a non-200 status, a JSON-RPC error or a
  /// body that is not a JSON-RPC response.
  Future<Object?> call(
    String endpoint,
    String method, {
    Map<String, Object?> params = const {},
  }) async {
    final response = await _http.post<Object?>(
      endpoint,
      data: {'jsonrpc': '2.0', 'id': '0', 'method': method, 'params': params},
    );
    if (response.statusCode != 200) {
      throw BbxApiHttpException(response.statusCode);
    }
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const BbxApiFormatException('response is not a JSON object');
    }
    if (body['error'] case final Object error) {
      throw BbxApiRpcException.fromJson(error);
    }
    return body['result'];
  }
}
