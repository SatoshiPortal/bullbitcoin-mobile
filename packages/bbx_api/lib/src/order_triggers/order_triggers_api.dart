import 'package:bbx_api/src/bbx_api_client.dart';
import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/order_triggers/dca.dart';
import 'package:bbx_api/src/order_triggers/limit_order.dart';

/// The `api-ordertrigger` endpoint: recurring buys and limit orders.
///
/// A limit order refusal carries its `ERR_` code in the JSON-RPC error's
/// `data.code`; it is kept as the [BbxApiRpcException.apiCode].
class OrderTriggersApi {
  static const endpoint = '/ak/api-ordertrigger';

  final BbxApiClient _client;

  OrderTriggersApi(this._client);

  /// Creates a recurring buy of [amount] in [currencyCode], paid out to
  /// [address].
  Future<Dca> createDca({
    required double amount,
    required String currencyCode,
    required DcaFrequency frequency,
    required DcaRecipientType recipientType,
    required String address,
  }) async {
    final result = read<Map<String, dynamic>>(
      await _client.call(
        endpoint,
        'createDCA',
        id: '1',
        params: {
          'element': {
            'amountStr': amount.toString(),
            'currencyCode': currencyCode,
            'recurringFrequency': frequency.value,
            'recipientType': recipientType.value,
            'address': address,
          },
        },
      ),
      'result',
    );
    return Dca.fromJson(
      read<Map<String, dynamic>>(result['element'], 'element'),
    );
  }

  /// One page of the user's limit orders, newest first. A missing element
  /// list is empty.
  Future<List<LimitOrder>> listLimitOrders({
    int page = 1,
    int pageSize = 50,
  }) async => _limitOrders(
    await _limitOrderCall('listLimitOrders', {
      'paginator': {'page': page, 'pageSize': pageSize},
      'sortBy': {'id': 'createdAt', 'sort': 'desc'},
    }),
  );

  /// The limit order [limitOrderId].
  Future<LimitOrder> getLimitOrder(String limitOrderId) async =>
      LimitOrder.fromJson(
        await _limitOrderCall('getLimitOrder', {'limitOrderId': limitOrderId}),
      );

  /// Places a limit order. Amounts and prices are sent as the given decimal
  /// strings.
  Future<LimitOrder> addLimitOrder({
    required String limitPrice,
    required String fiatAmount,
    required String currencyCode,
    required String estimatedBtcAmount,
    required String address,
  }) async => LimitOrder.fromJson(
    await _limitOrderCall('addLimitOrder', {
      'element': {
        'limitPrice': limitPrice,
        'fiatAmount': fiatAmount,
        'currencyCode': currencyCode,
        'estimatedBtcAmount': estimatedBtcAmount,
        'address': address,
      },
    }),
  );

  /// Cancels the limit order [limitOrderId] and returns it.
  Future<LimitOrder> cancelLimitOrder(String limitOrderId) async =>
      LimitOrder.fromJson(
        await _limitOrderCall('cancelLimitOrder', {
          'limitOrderId': limitOrderId,
        }),
      );

  /// Cancels every active limit order and returns them. A missing element
  /// list is empty.
  Future<List<LimitOrder>> cancelAllLimitOrders() async =>
      _limitOrders(await _limitOrderCall('cancelAllLimitOrders', const {}));

  Future<Map<String, dynamic>> _limitOrderCall(
    String method,
    Map<String, Object?> params,
  ) async => read<Map<String, dynamic>>(
    await _client.call(
      endpoint,
      method,
      params: params,
      rpcError: limitOrderRejection,
    ),
    'result',
  );

  static List<LimitOrder> _limitOrders(Map<String, dynamic> result) =>
      readList(result['elements'], 'elements', LimitOrder.fromJson);
}

/// Reads the JSON-RPC [error] of a limit order call. Its [BbxApiRpcException.apiCode]
/// is `data.code` when that is an `ERR_` code.
BbxApiRpcException limitOrderRejection(Object error) {
  final rpc = BbxApiRpcException.fromJson(error);
  final code = switch (error) {
    {'data': {'code': final String code}} when _apiCode.hasMatch(code) => code,
    _ => null,
  };
  return BbxApiRpcException(
    code: rpc.code,
    message: rpc.message,
    apiCode: code,
  );
}

final _apiCode = RegExp(r'^ERR_[A-Z0-9_]{1,64}$');
