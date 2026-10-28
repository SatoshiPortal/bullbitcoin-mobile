import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/mappers/bbx_api_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bb_mobile/features/dca/public/dca_facade.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';

/// [ExchangeOrderRepository] on the shared `bbx_api` client.
class BbxApiExchangeOrderRepository implements ExchangeOrderRepository {
  final BbxApiDatasource _api;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  BbxApiExchangeOrderRepository({
    required this._api,
    required this._apiKeyDatasource,
    required this._isTestnet,
  });

  @override
  Future<Order> getOrder(String orderId) async {
    try {
      await _requireApiKey(legacyMessages: true);
      return _toOrder(
        (await _api.orders.getOrderSummary(orderId: orderId)).unwrap(),
      );
    } on BbxApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to get order: $e');
    }
  }

  @override
  Future<Order?> getOrderByTxId(String txId) async {
    try {
      if (!await _hasActiveApiKey()) return null;

      // A wallet transaction with no matching order is the normal case, not an
      // error, so it must not be logged as one.
      final summary = (await _listOrderSummaries()).firstWhereOrNull(
        (summary) => BbxApiMapper.orderMatchesTxId(summary, txId),
      );
      if (summary == null) return null;

      return _toOrder(summary);
    } catch (e) {
      log.severe(
        message: 'Error fetching order by txId',
        error: e,
        trace: StackTrace.current,
      );
      return null;
    }
  }

  @override
  Future<List<Order>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  }) async {
    try {
      if (!await _hasActiveApiKey()) return [];

      final pageSize = limit ?? _orderPageSize;
      final skip = offset ?? 0;
      if (skip % pageSize != 0) {
        throw ArgumentError.value(offset, 'offset', 'not a multiple of limit');
      }
      final summaryType = type == null ? null : _summaryType(type);

      // Map each order on its own so one unmappable order does not drop all.
      List<Order> orders =
          (await _listOrderSummaries(
                page: skip ~/ pageSize + 1,
                pageSize: pageSize,
                orderType: summaryType,
              ))
              .map((summary) {
                try {
                  return _toOrder(summary);
                } catch (e, stackTrace) {
                  log.severe(
                    message: 'Error mapping order ${summary.orderId}',
                    error: e,
                    trace: stackTrace,
                  );
                  return null;
                }
              })
              .whereType<Order>()
              .toList();

      // The server cannot filter on a type this build does not know.
      if (type == OrderType.unknown) {
        orders = orders.where((o) => o.orderType == type).toList();
      }

      return orders;
    } catch (e) {
      log.severe(
        message: 'Error fetching orders',
        error: e,
        trace: StackTrace.current,
      );
      return [];
    }
  }

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
      await _requireApiKey();
      final summary = await _orderCall(
        'Failed to create buy order',
        () => _api.orders.createOrderBuy(
          params: bbx.CreateOrderBuyPayload(
            fiatCurrency: currency.code,
            fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
            bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
            network: _network(network),
            isOwner: isOwner,
            // The package drops the address when a bip21URI is set.
            address: toAddress,
            bip21URI: payjoinBip21,
          ),
        ),
      );
      return _toOrder(summary) as BuyOrder;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } on BbxApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to place buy order: $e');
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
      final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
      if (apiKey == null || !apiKey.isActive) {
        throw ApiKeyException(
          'API key not found or inactive. '
          'Please login to your Bull Bitcoin account.',
        );
      }
      final summary = await _orderCall(
        'Failed to create sell order',
        () => _api.orders.sellToBalance(
          params: bbx.SellToBalancePayload(
            fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
            bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
            bitcoinNetwork: _network(network),
            fiatCurrency: currency.code,
            usePayjoin: usePayjoin ? true : null,
          ),
        ),
      );
      return _toOrder(summary) as SellOrder;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } on BbxApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to place sell order: $e');
    }
  }

  /// Temporary EUR Sell counterpart to [placePayOrder] while the broader exchange refactor is underway.
  /// The duplicate entry point deliberately isolates Confidential SEPA processor selection from Pay's current contract; the refactor will consolidate these order-creation paths.
  @override
  Future<FiatPaymentOrder> placeSellToRecipientOrderV2({
    required OrderAmount orderAmount,
    required String recipientId,
    required SepaPaymentProcessor paymentProcessor,
    required OrderBitcoinNetwork network,
    bool usePayjoin = false,
  }) async {
    try {
      final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
      if (apiKey == null || !apiKey.isActive) {
        throw ApiKeyException(
          'API key not found or inactive. '
          'Please login to your Bull Bitcoin account.',
        );
      }
      final summary = await _orderCall(
        'Failed to create sell order',
        () => _api.orders.sellToRecipient(
          params: bbx.SellToRecipientPayload(
            fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
            bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
            bitcoinNetwork: _network(network),
            recipientId: recipientId,
            paymentProcessor: _sepaPaymentProcessor(paymentProcessor),
            usePayjoin: usePayjoin ? true : null,
          ),
        ),
        redactError: true,
      );
      // The API classifies bank payouts as Fiat Payment, including own-account Sell.
      final order = _toOrder(summary);
      if (order is! FiatPaymentOrder) {
        throw const FormatException('Invalid EUR sell payout order type');
      }
      return order;
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
    } on BbxApiException {
      rethrow;
    } catch (e, st) {
      Error.throwWithStackTrace(
        Exception('Failed to place EUR sell payout order (${e.runtimeType})'),
        st,
      );
    }
  }

  @override
  Future<FiatPaymentOrder> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required OrderBitcoinNetwork network,
    String? paymentDescription,
    bool usePayjoin = false,
  }) async {
    try {
      await _requireApiKey();
      final summary = await _orderCall(
        'Failed to create sell to recipient order',
        () => _api.orders.sellToRecipient(
          params: bbx.SellToRecipientPayload(
            fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
            bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
            bitcoinNetwork: _network(network),
            recipientId: recipientId,
            paymentDescription:
                paymentDescription != null && paymentDescription.isNotEmpty
                ? paymentDescription
                : null,
            usePayjoin: usePayjoin ? true : null,
          ),
        ),
      );
      return _toOrder(summary) as FiatPaymentOrder;
    } on BullBitcoinApiMinAmountException {
      rethrow;
    } on BullBitcoinApiMaxAmountException {
      rethrow;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      Error.throwWithStackTrace(Exception('Failed to place pay order: $e'), st);
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
      await _requireApiKey();
      final summary = await _orderCall(
        'Failed to create withdrawal order',
        () => _api.orders.createWithdrawalOrder(
          params: bbx.CreateWithdrawalOrderPayload(
            fiatAmount: fiatAmount,
            recipientId: recipientId,
            paymentProcessor: paymentProcessor == null
                ? null
                : _sepaPaymentProcessor(paymentProcessor),
            paymentProcessorData:
                securityQuestion != null && securityAnswer != null
                ? bbx.PaymentProcessorDataSell(
                    securityQuestion: securityQuestion,
                    securityAnswer: securityAnswer,
                  )
                : null,
          ),
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
    } catch (_, st) {
      // Error dropped: the request carries the Interac security answer.
      Error.throwWithStackTrace(
        Exception('Failed to create withdrawal order'),
        st,
      );
    }
  }

  @override
  Future<BuyOrder> confirmBuyOrder(String orderId) async {
    try {
      await _requireApiKey(legacyMessages: true);
      final order = _toOrder(
        (await _api.orders.confirmOrderSummary(orderId: orderId)).unwrap(),
      );
      if (order is! BuyOrder) throw UnexpectedOrderTypeException('BuyOrder');
      return order;
    } on ApiKeyException {
      rethrow;
    } on BbxApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to confirm buy order: $e');
    }
  }

  @override
  Future<WithdrawOrder> confirmWithdrawOrder(String orderId) async {
    try {
      await _requireApiKey();
      final order = _toOrder(
        (await _api.orders.confirmOrderSummary(orderId: orderId)).unwrap(),
      );
      if (order is! WithdrawOrder) {
        throw UnexpectedOrderTypeException('WithdrawOrder');
      }
      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      Error.throwWithStackTrace(
        Exception('Failed to confirm withdraw order: $e'),
        st,
      );
    }
  }

  @override
  Future<BuyOrder> refreshBuyOrder(String orderId) async {
    try {
      await _requireApiKey(legacyMessages: true);
      final order = await _refresh(orderId);
      if (order is! BuyOrder) throw UnexpectedOrderTypeException('BuyOrder');
      return order;
    } on ApiKeyException {
      rethrow;
    } on BbxApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to refresh order: $e');
    }
  }

  @override
  Future<SellOrder> refreshSellOrder(String orderId) async {
    try {
      await _requireApiKey(legacyMessages: true);
      final order = await _refresh(orderId);
      if (order is! SellOrder) {
        throw Exception(
          'Expected SellOrder but received a different order type',
        );
      }
      return order;
    } on ApiKeyException {
      rethrow;
    } on BbxApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to refresh sell order: $e');
    }
  }

  @override
  Future<FiatPaymentOrder> refreshPayOrder(String orderId) async {
    try {
      await _requireApiKey();
      final order = await _refresh(orderId);
      if (order is! FiatPaymentOrder) {
        throw UnexpectedOrderTypeException('FiatPaymentOrder');
      }
      return order;
    } on ApiKeyException {
      rethrow;
    } catch (e, st) {
      Error.throwWithStackTrace(
        Exception('Failed to refresh pay order: $e'),
        st,
      );
    }
  }

  @override
  Future<BuyOrder> accelerateBuyOrder(String orderId) async {
    try {
      await _requireApiKey(legacyMessages: true);
      final summary = (await _api.orders.unbatchAndExpressOrder(
        orderId: orderId,
      )).unwrap();
      return _toOrder(summary) as BuyOrder;
    } on ApiKeyException {
      rethrow;
    } on BbxApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to dequeue and pay order: $e');
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
      await _requireApiKey(legacyMessages: true);
      final dca = (await _api.orders.createDCA(
        params: bbx.CreateDCAOrderPayload(
          amountStr: amount.toString(),
          currencyCode: currency.code,
          recurringFrequency: switch (frequency) {
            DcaBuyFrequency.hourly => bbx.DCARecurringFrequencyType.hourly,
            DcaBuyFrequency.daily => bbx.DCARecurringFrequencyType.daily,
            DcaBuyFrequency.weekly => bbx.DCARecurringFrequencyType.weekly,
            DcaBuyFrequency.monthly => bbx.DCARecurringFrequencyType.monthly,
          },
          recipientType: switch (network) {
            DcaNetwork.bitcoin => bbx.RecipientType.outBitcoinAddress,
            DcaNetwork.lightning => bbx.RecipientType.outLightningAddress,
            DcaNetwork.liquid => bbx.RecipientType.outLiquidAddress,
          },
          address: address,
        ),
      )).unwrap();
      return BbxApiMapper.dcaFromRecurringBuy(dca);
    } on BbxApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create DCA: $e');
    }
  }

  Future<void> _requireApiKey({bool legacyMessages = false}) async {
    final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
    if (apiKey == null) {
      throw legacyMessages
          ? ApiKeyException(
              'API key not found. Please login to your Bull Bitcoin account.',
            )
          : ApiKeyNotFoundException();
    }
    if (!apiKey.isActive) {
      throw legacyMessages
          ? ApiKeyException(
              'API key is inactive. '
              'Please login again to your Bull Bitcoin account.',
            )
          : ApiKeyInactiveException();
    }
  }

  Future<bbx.OrderSummary> _orderCall(
    String contextMessage,
    Future<bbx.ApiResult<bbx.OrderSummary>> Function() call, {
    bool redactError = false,
  }) async {
    switch (await call()) {
      case bbx.Success(:final data):
        return data;
      case bbx.Failure(:final error):
        if (error.rpcErrorData == null) throw BbxApiException(error);
        _throwOrderApiError(error, contextMessage, redactError: redactError);
    }
  }

  Future<bool> _hasActiveApiKey() async {
    final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
    return apiKey != null && apiKey.isActive;
  }

  Future<List<bbx.OrderSummary>> _listOrderSummaries({
    int page = 1,
    int pageSize = _orderPageSize,
    bbx.OrderSummaryType? orderType,
  }) async {
    final list = (await _api.orders.listOrderSummaries(
      bbx.ListRequest(
        sortBy: bbx.SortBy.newestFirst(),
        paginator: bbx.Paginator(page: page, pageSize: pageSize),
        payload: orderType == null
            ? null
            : bbx.OrdersPayload(
                filters: bbx.ListOrderSummariesFilters(orderTypes: [orderType]),
              ),
      ),
    )).unwrap();
    return list.items;
  }

  static const _orderPageSize = 50;

  static bbx.OrderSummaryType? _summaryType(OrderType type) => switch (type) {
    OrderType.buy => bbx.OrderSummaryType.buyBitcoin,
    OrderType.sell => bbx.OrderSummaryType.sellBitcoin,
    OrderType.sellUsdt => bbx.OrderSummaryType.sellUsdt,
    OrderType.fiatPayment => bbx.OrderSummaryType.fiatPayment,
    OrderType.funding => bbx.OrderSummaryType.funding,
    OrderType.withdraw => bbx.OrderSummaryType.withdraw,
    OrderType.reward => bbx.OrderSummaryType.reward,
    OrderType.refund => bbx.OrderSummaryType.refund,
    OrderType.balanceAdjustment => bbx.OrderSummaryType.balanceAdjustment,
    OrderType.unknown => null,
  };

  Future<Order> _refresh(String orderId) async => _toOrder(
    (await _api.orders.refreshOrderSummary(orderId: orderId)).unwrap(),
  );

  Order _toOrder(bbx.OrderSummary summary) =>
      BbxApiMapper.orderFromSummary(summary, isTestnet: _isTestnet);

  static bbx.SepaPaymentProcessor _sepaPaymentProcessor(
    SepaPaymentProcessor processor,
  ) => switch (processor) {
    SepaPaymentProcessor.regular => bbx.SepaPaymentProcessor.regular,
    SepaPaymentProcessor.confidential => bbx.SepaPaymentProcessor.confidential,
  };

  static bbx.BitcoinNetworkEndUser _network(OrderBitcoinNetwork network) =>
      switch (network) {
        OrderBitcoinNetwork.bitcoin => bbx.BitcoinNetworkEndUser.bitcoin,
        OrderBitcoinNetwork.liquid => bbx.BitcoinNetworkEndUser.liquid,
        OrderBitcoinNetwork.lightning => bbx.BitcoinNetworkEndUser.lightning,
      };
}

/// Translates an orders API error into a typed exception. Always throws: an
/// error response must never fall through to parsing `result`.
///
/// A limit is read only from a single rejected payment option. When several
/// options are rejected the server sends no limit, so that reaches the generic
/// error.
Never _throwOrderApiError(
  bbx.ApiError error,
  String contextMessage, {
  bool redactError = false,
}) {
  final apiCode = error.apiErrorCode;
  if (bbx.BBApiErrorCode.fromString(apiCode) ==
      bbx.BBApiErrorCode.errOrdCsrcp400) {
    throw const BullBitcoinApiConfidentialSepaNotActivatedException();
  }

  final limit = error.orderLimitRejection;
  if (limit != null && limit.isMinimum) {
    throw BullBitcoinApiMinAmountException(
      minAmount: limit.amount,
      currency: limit.currencyCode,
    );
  }
  if (limit != null && limit.isMaximum) {
    throw BullBitcoinApiMaxAmountException(
      maxAmount: limit.amount,
      currency: limit.currencyCode,
    );
  }

  if (redactError) {
    throw BullBitcoinApiOrderException(
      apiCode:
          apiCode != null && RegExp(r'^ERR_[A-Z0-9_]{1,64}$').hasMatch(apiCode)
          ? apiCode
          : null,
    );
  }

  throw Exception(contextMessage);
}
