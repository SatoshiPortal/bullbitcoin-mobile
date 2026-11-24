import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/order_triggers/dca.dart';
import 'package:bbx_api/src/order_triggers/limit_order.dart';
import 'package:bbx_api/src/order_triggers/order_triggers_wire.dart';
import 'package:bbx_api/src/rpc_error.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The `api-ordertrigger` endpoint: recurring buys and limit orders.
///
/// A limit order refusal carries its `ERR_` code in the JSON-RPC error's
/// `data.code`; it is kept as the [BbxRpcFailure.apiCode].
final class OrderTriggersApi {
  static const endpoint = '/ak/api-ordertrigger';

  final BbxTransport _transport;

  @internal
  OrderTriggersApi(this._transport);

  /// Creates a recurring buy of [amount] in [currencyCode], paid out to
  /// [address].
  Future<Result<Dca, BbxFailure>> createDca({
    required double amount,
    required String currencyCode,
    required DcaFrequency frequency,
    required DcaRecipientType recipientType,
    required String address,
  }) => _transport.request(
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
    read: (result) {
      final element = read<Map<String, dynamic>>(result, 'result');
      return parseDca(
        read<Map<String, dynamic>>(element['element'], 'element'),
      );
    },
  );

  /// One page of the user's limit orders, newest first. A missing element
  /// list is empty.
  Future<Result<List<LimitOrder>, BbxFailure>> listLimitOrders({
    int page = 1,
    int pageSize = 50,
  }) => _limitOrderCall('listLimitOrders', {
    'paginator': {'page': page, 'pageSize': pageSize},
    'sortBy': {'id': 'createdAt', 'sort': 'desc'},
  }, parse: _limitOrders);

  /// The limit order [limitOrderId].
  Future<Result<LimitOrder, BbxFailure>> getLimitOrder(String limitOrderId) =>
      _limitOrderCall('getLimitOrder', {
        'limitOrderId': limitOrderId,
      }, parse: parseLimitOrder);

  /// Places a limit order. Amounts and prices are sent as the given decimal
  /// strings.
  Future<Result<LimitOrder, BbxFailure>> addLimitOrder({
    required String limitPrice,
    required String fiatAmount,
    required String currencyCode,
    required String estimatedBtcAmount,
    required String address,
  }) => _limitOrderCall('addLimitOrder', {
    'element': {
      'limitPrice': limitPrice,
      'fiatAmount': fiatAmount,
      'currencyCode': currencyCode,
      'estimatedBtcAmount': estimatedBtcAmount,
      'address': address,
    },
  }, parse: parseLimitOrder);

  /// Cancels the limit order [limitOrderId] and returns it.
  Future<Result<LimitOrder, BbxFailure>> cancelLimitOrder(
    String limitOrderId,
  ) => _limitOrderCall('cancelLimitOrder', {
    'limitOrderId': limitOrderId,
  }, parse: parseLimitOrder);

  /// Cancels every active limit order and returns them. A missing element
  /// list is empty.
  Future<Result<List<LimitOrder>, BbxFailure>> cancelAllLimitOrders() =>
      _limitOrderCall('cancelAllLimitOrders', const {}, parse: _limitOrders);

  Future<Result<T, BbxFailure>> _limitOrderCall<T>(
    String method,
    Map<String, Object?> params, {
    required T Function(Map<String, dynamic> element) parse,
  }) => _transport.request(
    endpoint,
    method,
    params: params,
    rejection: limitOrderRejection,
    read: (result) => parse(read<Map<String, dynamic>>(result, 'result')),
  );

  static List<LimitOrder> _limitOrders(Map<String, dynamic> result) =>
      readList(result['elements'], 'elements', parseLimitOrder);
}

/// Reads the JSON-RPC [error] of a limit order call. Its
/// [BbxRpcFailure.apiCode] is `data.code` when that is an `ERR_` code.
BbxFailure limitOrderRejection(Object error) {
  final rpc = bbxRpcFailure(error);
  final code = switch (error) {
    {'data': {'code': final String code}} => bbxApiCode(code),
    _ => null,
  };
  return BbxRpcFailure(
    code: rpc.code,
    message: rpc.message,
    apiCode: code,
    requestId: rpc.requestId,
  );
}
