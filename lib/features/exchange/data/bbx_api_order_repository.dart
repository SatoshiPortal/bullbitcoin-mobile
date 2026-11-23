import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_order_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:primitives/generic_extensions.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_order_mapper.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

class _OrderRequestException implements Exception {
  final String message;

  const _OrderRequestException(this.message);

  @override
  String toString() => 'Exception: $message';
}

/// [ExchangeOrderRepository] on the `bbx_api` package.
class BbxApiOrderRepository implements ExchangeOrderRepository {
  final bbx.Bbx _api;
  final bool _isTestnet;

  BbxApiOrderRepository({required this._api, required this._isTestnet});

  @override
  Future<Order> getOrder(String orderId) async {
    try {
      return _toOrder(await _required(_api.orders.getOrderSummary(orderId)));
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to get order: ${_describe(e)}');
    }
  }

  @override
  Future<Result<Order?, ExchangeOrderFailure>> getOrderByTxId(
    String txId,
  ) async {
    try {
      // A wallet transaction with no matching order is the normal case, not an
      // error, so it must not be logged as one.
      final summary = (await _listOrderSummaries()).firstWhereOrNull(
        (summary) => orderSummaryMatchesTxId(summary, txId),
      );
      if (summary == null) return const Ok(null);

      return Ok(_toOrder(summary));
    } on Exception catch (e) {
      final refusal = exchangeAuthenticationException(e);
      if (refusal != null) {
        return refusal.isUnauthenticated
            ? const Ok(null)
            : const Err(ExchangeOrderCredentialFailure());
      }
      log.warning('Exchange order lookup failed: ${e.runtimeType}');
      return const Err(ExchangeOrderLoadFailure());
    }
  }

  @override
  Future<Result<List<Order>, ExchangeOrderFailure>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    try {
      final summaries = await _listOrderSummaries();

      // Preserve the remaining history when one order cannot be mapped.
      List<Order> orders = summaries
          .map((summary) {
            try {
              return _toOrder(summary);
            } catch (e, stackTrace) {
              log.severe(
                message: 'Error mapping exchange order',
                error: e.runtimeType.toString(),
                trace: stackTrace,
              );
              return null;
            }
          })
          .whereType<Order>()
          .toList();

      if (type != null) {
        switch (type) {
          case OrderType.buy:
            orders = orders.whereType<BuyOrder>().toList();
          case OrderType.sell:
            orders = orders.whereType<SellOrder>().toList();
          case OrderType.fiatPayment:
            orders = orders.whereType<FiatPaymentOrder>().toList();
          case OrderType.funding:
            orders = orders.whereType<FundingOrder>().toList();
          case OrderType.withdraw:
            orders = orders.whereType<WithdrawOrder>().toList();
          case OrderType.reward:
            orders = orders.whereType<RewardOrder>().toList();
          case OrderType.refund:
            orders = orders.whereType<RefundOrder>().toList();
          case OrderType.balanceAdjustment:
            orders = orders.whereType<BalanceAdjustmentOrder>().toList();
          case OrderType.sellUsdt:
          case OrderType.unknown:
            // Both map onto GenericOrder, so match on the type itself.
            orders = orders.where((o) => o.orderType == type).toList();
        }
      }

      if (offset != null || limit != null) {
        final startIndex = offset ?? 0;
        final endIndex = limit != null ? startIndex + limit : orders.length;

        if (startIndex < orders.length) {
          orders = orders.sublist(startIndex, endIndex.clamp(0, orders.length));
        } else {
          orders = [];
        }
      }

      return Ok(orders);
    } on Exception catch (e) {
      final refusal = exchangeAuthenticationException(e);
      if (refusal != null) {
        return refusal.isUnauthenticated
            ? const Ok([])
            : const Err(ExchangeOrderCredentialFailure());
      }
      log.warning('Exchange order history failed: ${e.runtimeType}');
      return const Err(ExchangeOrderLoadFailure());
    }
  }

  @override
  Future<BuyOrder> refreshBuyOrder(String orderId) async {
    try {
      final order = await _refresh(orderId);
      if (order is! BuyOrder) {
        throw UnexpectedOrderTypeException('BuyOrder');
      }
      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to refresh order: ${_describe(e)}');
    }
  }

  @override
  Future<SellOrder> refreshSellOrder(String orderId) async {
    try {
      final order = await _refresh(orderId);
      if (order is! SellOrder) {
        throw const _OrderRequestException(
          'Expected SellOrder but received a different order type',
        );
      }
      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to refresh sell order: ${_describe(e)}');
    }
  }

  @override
  Future<FiatPaymentOrder> refreshPayOrder(String orderId) async {
    try {
      final order = await _refresh(orderId);
      if (order is! FiatPaymentOrder) {
        throw UnexpectedOrderTypeException('FiatPaymentOrder');
      }
      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      // Keep the original trace: the use-case logs the trace it catches.
      Error.throwWithStackTrace(
        Exception('Failed to refresh pay order: ${_describe(e)}'),
        st,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getBuyLimits() async {
    try {
      return _limitsJson(await _required(_api.orders.getBuyLimits()));
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to get buy limits: ${_describe(e)}');
    }
  }

  @override
  Future<Map<String, dynamic>> getSellLimits() async {
    try {
      return _limitsJson(await _required(_api.orders.getSellLimits()));
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to get sell limits: ${_describe(e)}');
    }
  }

  /// [ExchangeOrderRepository] predates the package owning the limits type and
  /// still carries them as a JSON object, so they are unwrapped here.
  static Map<String, dynamic> _limitsJson(bbx.OrderLimits limits) => {
    'min': ?limits.minimum,
    'max': ?limits.maximum,
    if (limits.currencyLimits.isNotEmpty)
      'limits': {
        for (final currency in limits.currencyLimits)
          currency.currencyCode: currency.values,
      },
  };

  @override
  Future<BuyOrder> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    required bool isOwner,
    String? payjoinBip21,
  }) async {
    try {
      final summary = await _placeOrder(
        'Failed to create buy order',
        () => _api.orders.createOrderBuy(
          fiatCurrency: currency.code,
          network: network.value,
          isOwner: isOwner,
          address: payjoinBip21 == null ? toAddress : null,
          bip21URI: payjoinBip21,
          fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
          bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
        ),
      );
      return _toOrder(summary) as BuyOrder;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to place buy order: ${_describe(e)}');
    }
  }

  @override
  Future<SellOrder> placeSellOrder({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    bool usePayjoin = false,
  }) async {
    try {
      final summary = await _placeOrder(
        'Failed to create sell order',
        () => _api.orders.sellToBalance(
          fiatCurrency: currency.code,
          bitcoinNetwork: network.value,
          usePayjoin: usePayjoin,
          fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
          bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
        ),
      );
      return _toOrder(summary) as SellOrder;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to place sell order: ${_describe(e)}');
    }
  }

  @override
  Future<FiatPaymentOrder> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required OrderBitcoinNetwork network,
    String? paymentDescription,
    SepaPaymentProcessor? paymentProcessor,
    bool usePayjoin = false,
  }) async {
    try {
      final summary = await _placeOrder(
        'Failed to create sell to recipient order',
        () => _api.orders.sellToRecipient(
          recipientId: recipientId,
          paymentProcessor: _sepaPaymentProcessor(paymentProcessor),
          bitcoinNetwork: network.value,
          usePayjoin: usePayjoin,
          fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
          bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
          paymentDescription:
              paymentDescription != null && paymentDescription.isNotEmpty
              ? paymentDescription
              : null,
        ),
        redactError: true,
      );
      return _toOrder(summary) as FiatPaymentOrder;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on BullBitcoinApiConfidentialSepaNotActivatedException {
      rethrow;
    } on BullBitcoinApiOrderException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      // Keep the original trace: see refreshPayOrder.
      Error.throwWithStackTrace(
        Exception('Failed to place pay order: ${_describe(e)}'),
        st,
      );
    }
  }

  @override
  Future<WithdrawOrder> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    SepaPaymentProcessor? paymentProcessor,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    try {
      final summary = await _placeOrder(
        'Failed to create withdrawal order',
        () => _api.orders.createWithdrawalOrder(
          fiatAmount: fiatAmount,
          recipientId: recipientId,
          paymentProcessor: _sepaPaymentProcessor(paymentProcessor),
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
        ),
      );
      return _toOrder(summary) as WithdrawOrder;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on BullBitcoinApiConfidentialSepaNotActivatedException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      // Keep the original trace. The error itself is dropped because the
      // request carries the Interac security answer.
      Error.throwWithStackTrace(
        Exception('Failed to create withdrawal order'),
        st,
      );
    }
  }

  @override
  Future<BuyOrder> confirmBuyOrder(String orderId) async {
    try {
      final order = _toOrder(
        await _required(_api.orders.confirmOrderSummary(orderId)),
      );
      if (order is! BuyOrder) {
        throw UnexpectedOrderTypeException('BuyOrder');
      }
      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to confirm buy order: ${_describe(e)}');
    }
  }

  @override
  Future<WithdrawOrder> confirmWithdrawOrder(String orderId) async {
    try {
      final order = _toOrder(
        await _required(_api.orders.confirmOrderSummary(orderId)),
      );
      if (order is! WithdrawOrder) {
        throw UnexpectedOrderTypeException('WithdrawOrder');
      }
      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      // Keep the original trace: see refreshPayOrder.
      Error.throwWithStackTrace(
        Exception('Failed to confirm withdraw order: ${_describe(e)}'),
        st,
      );
    }
  }

  @override
  Future<BuyOrder> accelerateBuyOrder(String orderId) async {
    try {
      return _toOrder(
        await _required(_api.orders.unbatchAndExpressOrder(orderId)),
      ) as BuyOrder;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to dequeue and pay order: ${_describe(e)}');
    }
  }

  @override
  Future<Dca> createDca({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required DcaNetwork network,
    required String address,
  }) async {
    try {
      return _toDca(
        await _required(
          _api.orderTriggers.createDca(
            amount: amount,
            currencyCode: currency.code,
            frequency: switch (frequency) {
              DcaBuyFrequency.hourly => bbx.DcaFrequency.hourly,
              DcaBuyFrequency.daily => bbx.DcaFrequency.daily,
              DcaBuyFrequency.weekly => bbx.DcaFrequency.weekly,
              DcaBuyFrequency.monthly => bbx.DcaFrequency.monthly,
            },
            recipientType: switch (network) {
              DcaNetwork.bitcoin => bbx.DcaRecipientType.bitcoinAddress,
              DcaNetwork.lightning => bbx.DcaRecipientType.lightningAddress,
              DcaNetwork.liquid => bbx.DcaRecipientType.liquidAddress,
            },
            address: address,
          ),
        ),
      );
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      throw Exception('Failed to create DCA: ${_describe(e)}');
    }
  }

  static Dca _toDca(bbx.Dca dca) => Dca(
    amount: double.parse(dca.amountStr),
    currency: FiatCurrency.fromCode(dca.currencyCode),
    frequency: switch (dca.recurringFrequency) {
      'HOURLY' => DcaBuyFrequency.hourly,
      'DAILY' => DcaBuyFrequency.daily,
      'WEEKLY' => DcaBuyFrequency.weekly,
      'MONTHLY' => DcaBuyFrequency.monthly,
      _ => throw const _OrderRequestException('Unknown DCA frequency'),
    },
    network: switch (dca.recipientType) {
      'OUT_BITCOIN_ADDRESS' => DcaNetwork.bitcoin,
      'OUT_LIGHTNING_ADDRESS' => DcaNetwork.lightning,
      'OUT_LIQUID_ADDRESS' => DcaNetwork.liquid,
      _ => throw const _OrderRequestException('Unknown DCA network'),
    },
    address: dca.address,
    nextPurchaseDate: DateTime.parse(dca.nextRunAt),
  );

  /// Runs an order creation [call] and turns the server's refusal into the
  /// app's order exception. With [redactError], an RPC refusal keeps only
  /// its codes.
  static Future<bbx.OrderSummary> _placeOrder(
    String contextMessage,
    Future<Result<bbx.OrderSummary, bbx.BbxFailure>> Function() call, {
    bool redactError = false,
  }) async {
    final result = await call();
    return switch (result) {
      Ok(:final value) => value,
      Err(failure: bbx.BbxMissingCredentialFailure()) =>
        throw const ExchangeAuthenticationException(),
      Err(failure: bbx.BbxCredentialUnavailableFailure()) =>
        throw const ExchangeCredentialUnavailableException(),
      Err(failure: bbx.BbxConfidentialSepaInactiveFailure()) =>
        throw const BullBitcoinApiConfidentialSepaNotActivatedException(),
      Err(
        failure: bbx.BbxOrderLimitFailure(
          bound: bbx.BbxOrderLimitBound.minimum,
          :final amount,
          :final currency,
        ),
      ) =>
        throw BullBitcoinApiMinAmountException(
          minAmount: amount,
          currency: currency,
        ),
      Err(
        failure: bbx.BbxOrderLimitFailure(
          bound: bbx.BbxOrderLimitBound.maximum,
          :final amount,
          :final currency,
        ),
      ) =>
        throw BullBitcoinApiMaxAmountException(
          maxAmount: amount,
          currency: currency,
        ),
      Err(
        failure: bbx.BbxRpcFailure(
          :final apiCode,
          :final code,
          :final requestId,
        ),
      )
          when redactError =>
        throw BullBitcoinApiOrderException(
          apiCode: apiCode,
          rpcCode: code,
          requestId: requestId,
        ),
      // The server's message can quote the request, so it is not kept. Other
      // failures retain their safe transport or format classification.
      Err(:final failure) => _throwRequest(
        failure is bbx.BbxRpcFailure
            ? '$contextMessage${failure.requestIdLabel}'
            : _describe(failure),
        failure.origin,
      ),
    };
  }

  /// Compatibility boundary for repository contracts that predate [Result].
  /// The transport itself only exposes failures as values.
  static Future<T> _required<T>(Future<Result<T, bbx.BbxFailure>> call) async {
    final result = await call;
    return switch (result) {
      Ok(:final value) => value,
      Err(failure: bbx.BbxMissingCredentialFailure()) =>
        throw const ExchangeAuthenticationException(),
      Err(failure: bbx.BbxCredentialUnavailableFailure()) =>
        throw const ExchangeAuthenticationException(
          ExchangeApiKeyReadFailure(),
        ),
      Err(:final failure) => _throwRequest(_describe(failure), failure.origin),
    };
  }

  static Never _throwRequest(String message, StackTrace? origin) {
    Error.throwWithStackTrace(
      _OrderRequestException(message),
      origin ?? StackTrace.current,
    );
  }

  static bbx.SepaPaymentProcessor? _sepaPaymentProcessor(
    SepaPaymentProcessor? processor,
  ) => switch (processor) {
    null => null,
    SepaPaymentProcessor.regular => bbx.SepaPaymentProcessor.regular,
    SepaPaymentProcessor.confidential => bbx.SepaPaymentProcessor.confidential,
  };

  Future<Order> _refresh(String orderId) async =>
      _toOrder(await _required(_api.orders.refreshOrderSummary(orderId)));

  /// One page of orders. Elements the package could not read are logged and
  /// left out.
  Future<List<bbx.OrderSummary>> _listOrderSummaries() async {
    final list = await _required(_api.orders.listOrderSummaries());
    for (final rejected in list.rejected) {
      log.severe(
        message: 'Error parsing order element',
        error: rejected.runtimeType.toString(),
        trace: StackTrace.current,
      );
    }
    return list.orders;
  }

  Order _toOrder(bbx.OrderSummary summary) =>
      orderFromBbxApi(summary, isTestnet: _isTestnet);

  /// A JSON-RPC error message can quote the request, so only its code is
  /// kept in exception messages.
  static String _describe(Object e) => switch (e) {
    bbx.BbxRpcFailure(:final code, :final requestIdLabel) =>
      'BbxRpcFailure(code: $code)$requestIdLabel',
    bbx.BbxTimeoutFailure(:final kind) =>
      'DioException(${switch (kind) {
        bbx.BbxTimeoutKind.connect => 'connectionTimeout',
        bbx.BbxTimeoutKind.send => 'sendTimeout',
        bbx.BbxTimeoutKind.receive => 'receiveTimeout',
      }})',
    bbx.BbxConnectionFailure() => 'DioException(connectionError)',
    bbx.BbxBadCertificateFailure() => 'DioException(badCertificate)',
    bbx.BbxHttpFailure(:final status) =>
      'DioException(badResponse, status: $status)',
    bbx.BbxRequestCancelledFailure() => 'DioException(cancel)',
    UnexpectedOrderTypeException() || _OrderRequestException() => e.toString(),
    _ => e.runtimeType.toString(),
  };
}
