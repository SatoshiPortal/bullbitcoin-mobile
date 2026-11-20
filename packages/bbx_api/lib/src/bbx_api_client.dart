import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/commcenter/commcenter_api.dart';
import 'package:bbx_api/src/order_triggers/order_triggers_api.dart';
import 'package:bbx_api/src/orders/orders_api.dart';
import 'package:bbx_api/src/prices/prices_api.dart';
import 'package:bbx_api/src/recipients/recipients_api.dart';
import 'package:bbx_api/src/users/users_api.dart';
import 'package:dio/dio.dart';

/// JSON-RPC 2.0 over the Bull Bitcoin API.
///
/// The [Dio] client is configured by the caller: base URL, timeouts and
/// authentication. A [DioException], including a refusal raised by the
/// caller's own interceptors, is rethrown unchanged.
class BbxApiClient {
  final Dio _http;

  BbxApiClient(this._http);

  late final CommcenterApi commcenter = CommcenterApi(this);
  late final OrderTriggersApi orderTriggers = OrderTriggersApi(this);
  late final OrdersApi orders = OrdersApi(this);
  late final PricesApi prices = PricesApi(this);
  late final RecipientsApi recipients = RecipientsApi(this);
  late final UsersApi users = UsersApi(this);

  /// Calls [method] on [endpoint] and returns the JSON-RPC `result`.
  ///
  /// Throws a [BbxApiException] for a non-200 status, a JSON-RPC error or a
  /// body that is not a JSON-RPC response. [rpcError] reads the JSON-RPC
  /// error object into the exception to throw. [id] is the JSON-RPC request
  /// id. [headers] are added to the request's headers.
  Future<Object?> call(
    String endpoint,
    String method, {
    Map<String, Object?> params = const {},
    String id = '0',
    Map<String, Object?>? headers,
    BbxApiRpcException Function(Object error) rpcError =
        BbxApiRpcException.fromJson,
  }) async {
    final response = await _http.post<Object?>(
      endpoint,
      data: {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params},
      options: headers == null ? null : Options(headers: headers),
    );
    if (response.statusCode != 200) {
      throw BbxApiHttpException(response.statusCode);
    }
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const BbxApiFormatException('response is not a JSON object');
    }
    if (body['error'] case final Object error) {
      throw rpcError(error);
    }
    return body['result'];
  }
}
