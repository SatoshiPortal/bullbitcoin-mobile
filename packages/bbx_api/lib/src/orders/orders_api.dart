import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/bbx_format_exception.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/orders/order_limits.dart';
import 'package:bbx_api/src/orders/order_rejection.dart';
import 'package:bbx_api/src/orders/order_stats.dart';
import 'package:bbx_api/src/orders/order_summary.dart';
import 'package:bbx_api/src/orders/orders_wire.dart';
import 'package:bbx_api/src/rpc_error.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The `api-orders` endpoint.
final class OrdersApi {
  static const endpoint = '/ak/api-orders';

  final BbxTransport _transport;

  @internal
  OrdersApi(this._transport);

  /// The user's trading statistics.
  Future<Result<OrderStatsReport, BbxFailure>> getOrderStats() =>
      _transport.request(
        endpoint,
        'getOrderStats',
        read: (result) => parseOrderStatsReport(
          read<Map<String, dynamic>>(
            read<Map<String, dynamic>>(result, 'result')['element'],
            'element',
          ),
        ),
      );

  /// The order [orderId]. The server wraps it in `element` or returns it as
  /// the result itself; both are read.
  Future<Result<OrderSummary, BbxFailure>> getOrderSummary(String orderId) =>
      _transport.request(
        endpoint,
        'getOrderSummary',
        params: {'orderId': orderId},
        read: (result) {
          final element = read<Map<String, dynamic>>(result, 'result');
          return parseOrderSummary(
            read<Map<String, dynamic>>(
              element['element'] ?? element,
              'element',
            ),
          );
        },
      );

  /// Asks the server to re-check the order [orderId] and returns it.
  Future<Result<OrderSummary, BbxFailure>> refreshOrderSummary(
    String orderId,
  ) => _transport.request(
    endpoint,
    'refreshOrderSummary',
    params: {'orderId': orderId},
    read: (result) =>
        parseOrderSummary(read<Map<String, dynamic>>(result, 'result')),
  );

  /// One page of the user's orders, newest first. A missing element list is
  /// empty.
  Future<Result<OrderSummaryList, BbxFailure>> listOrderSummaries({
    int page = 1,
    int pageSize = 50,
  }) => _transport.request(
    endpoint,
    'listOrderSummaries',
    params: {
      'sortBy': {'id': 'createdAt', 'sort': 'desc'},
      'paginator': {'page': page, 'pageSize': pageSize},
    },
    read: (result) {
      final element = read<Map<String, dynamic>>(result, 'result');
      final elements = element['elements'];
      if (elements == null) return const OrderSummaryList(orders: []);
      final orders = <OrderSummary>[];
      final rejected = <BbxResponseFormatFailure>[];
      for (final order in read<List<dynamic>>(elements, 'elements')) {
        try {
          orders.add(
            parseOrderSummary(read<Map<String, dynamic>>(order, 'elements')),
          );
        } on BbxFormatException catch (e) {
          rejected.add(BbxResponseFormatFailure(e.reason));
        }
      }
      return OrderSummaryList(orders: orders, rejected: rejected);
    },
  );

  /// The user's buy limits.
  Future<Result<OrderLimits, BbxFailure>> getBuyLimits() => _transport.request(
    endpoint,
    'getBuyLimits',
    read: (result) =>
        parseOrderLimits(read<Map<String, dynamic>>(result, 'result')),
  );

  /// The user's sell limits.
  Future<Result<OrderLimits, BbxFailure>> getSellLimits() => _transport.request(
    endpoint,
    'getSellLimits',
    read: (result) =>
        parseOrderLimits(read<Map<String, dynamic>>(result, 'result')),
  );

  /// Creates a buy order paid out to [network].
  ///
  /// Exactly one of [address] and [bip21URI] must be given: the server takes
  /// the payout address from the URI, and a payjoin buy has to send the URI.
  /// Fails with a [BbxOrderLimitFailure] when the amount is outside a limit.
  Future<Result<OrderSummary, BbxFailure>> createOrderBuy({
    required String fiatCurrency,
    required String network,
    required bool isOwner,
    String? address,
    String? bip21URI,
    double? fiatAmount,
    double? bitcoinAmount,
  }) async {
    if ((address == null) == (bip21URI == null)) {
      throw ArgumentError(
        'createOrderBuy takes an address or a bip21URI, never both and never '
        'neither',
      );
    }
    return _createOrder('createOrderBuy', {
      'fiatCurrency': fiatCurrency,
      'network': network,
      'isOwner': isOwner,
      if (bip21URI != null) 'bip21URI': bip21URI else 'address': address,
      ..._amount(fiatAmount: fiatAmount, bitcoinAmount: bitcoinAmount),
    });
  }

  /// Creates a sell order paid out to the user's fiat balance.
  ///
  /// [usePayjoin] asks the server to receive the payin through payjoin; it is
  /// sent only when true. Fails with a [BbxOrderLimitFailure] when the amount
  /// is outside a limit.
  Future<Result<OrderSummary, BbxFailure>> sellToBalance({
    required String fiatCurrency,
    required String bitcoinNetwork,
    bool usePayjoin = false,
    double? fiatAmount,
    double? bitcoinAmount,
  }) => _createOrder('sellToBalance', {
    'fiatCurrency': fiatCurrency,
    'bitcoinNetwork': bitcoinNetwork,
    if (usePayjoin) 'usePayjoin': true,
    ..._amount(fiatAmount: fiatAmount, bitcoinAmount: bitcoinAmount),
  });

  /// Creates a sell order paid out to the recipient [recipientId].
  ///
  /// See [sellToBalance] for [usePayjoin]. Fails with a
  /// [BbxOrderLimitFailure] or a [BbxConfidentialSepaInactiveFailure].
  Future<Result<OrderSummary, BbxFailure>> sellToRecipient({
    required String recipientId,
    required String bitcoinNetwork,
    SepaPaymentProcessor? paymentProcessor,
    bool usePayjoin = false,
    double? fiatAmount,
    double? bitcoinAmount,
    String? paymentDescription,
  }) => _createOrder('sellToRecipient', {
    'recipientId': recipientId,
    if (paymentProcessor != null) 'paymentProcessor': paymentProcessor.value,
    'bitcoinNetwork': bitcoinNetwork,
    if (usePayjoin) 'usePayjoin': true,
    ..._amount(fiatAmount: fiatAmount, bitcoinAmount: bitcoinAmount),
    'paymentDescription': ?paymentDescription,
  });

  /// Creates a withdrawal of [fiatAmount] from the fiat balance to the
  /// recipient [recipientId].
  ///
  /// The Interac security question and answer are sent only together. Fails
  /// with a [BbxOrderLimitFailure] or a [BbxConfidentialSepaInactiveFailure].
  Future<Result<OrderSummary, BbxFailure>> createWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    SepaPaymentProcessor? paymentProcessor,
    String? securityQuestion,
    String? securityAnswer,
  }) => _createOrder('createWithdrawalOrder', {
    'fiatAmount': fiatAmount,
    'recipientId': recipientId,
    if (paymentProcessor != null) 'paymentProcessor': paymentProcessor.value,
    if (securityQuestion != null && securityAnswer != null)
      'paymentProcessorData': {
        'securityQuestion': securityQuestion,
        'securityAnswer': securityAnswer,
      },
  });

  /// The payment link for a COP bank transfer of [amount] pesos from the
  /// bank [bankCode]; the bank sends the user back to [callbackUrl].
  ///
  /// The request also carries `paymentProcessorCode` as null, like the app
  /// always sent it.
  Future<Result<String, BbxFailure>> getCopPaymentLink({
    required String bankCode,
    required int amount,
    required String callbackUrl,
  }) => _transport.request(
    endpoint,
    'getCopPaymentLink',
    params: {
      'paymentProcessorCode': null,
      'bankCode': bankCode,
      'amount': amount,
      'callbackUrl': callbackUrl,
    },
    read: (result) => read<String>(result, 'result'),
  );

  /// Confirms the order [orderId] and returns it.
  Future<Result<OrderSummary, BbxFailure>> confirmOrderSummary(
    String orderId,
  ) => _orderCall('confirmOrderSummary', {'orderId': orderId});

  /// Takes the buy order [orderId] out of its payout batch and pays it now.
  Future<Result<OrderSummary, BbxFailure>> unbatchAndExpressOrder(
    String orderId,
  ) => _orderCall('unbatchAndExpressOrder', {'orderId': orderId});

  Future<Result<OrderSummary, BbxFailure>> _createOrder(
    String method,
    Map<String, Object?> params,
  ) => _orderCall(method, params, rejection: orderRejection);

  Future<Result<OrderSummary, BbxFailure>> _orderCall(
    String method,
    Map<String, Object?> params, {
    BbxFailure Function(Object error) rejection = bbxRpcFailure,
  }) => _transport.request(
    endpoint,
    method,
    params: params,
    rejection: rejection,
    read: (result) =>
        parseOrderSummary(read<Map<String, dynamic>>(result, 'result')),
  );

  static Map<String, Object?> _amount({
    double? fiatAmount,
    double? bitcoinAmount,
  }) => {
    'fiatAmount': ?fiatAmount,
    if (fiatAmount == null) 'bitcoinAmount': ?bitcoinAmount,
  };
}

/// The SEPA rail of a EUR payout.
enum SepaPaymentProcessor {
  regular('REGULAR_SEPA'),
  confidential('CONFIDENTIAL_SEPA');

  /// The wire value.
  final String value;

  const SepaPaymentProcessor(this.value);
}
