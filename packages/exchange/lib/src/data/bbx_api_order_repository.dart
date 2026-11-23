import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/catalog/exchange_catalog.dart';
import '../domain/entities/btc_network.dart';
import '../domain/entities/dca.dart';
import '../domain/entities/order.dart';
import '../domain/entities/sepa_payment_processor.dart';
import '../domain/exchange_failure.dart';
import '../domain/exchange_orders.dart';
import 'bbx_api_order_mapper.dart';
import 'btc_network_wire.dart';

typedef RunOrderOperation = Future<Result<T, ExchangeFailure>> Function<T>(
  Future<Result<T, ExchangeFailure>> Function(bbx.Bbx),
);

final class BbxApiOrderRepository implements ExchangeOrders {
  static const _maximumPages = 1000;
  final RunOrderOperation _read;
  final RunOrderOperation _write;
  final bool _isTestnet;

  BbxApiOrderRepository({
    required this._read,
    required this._write,
    required this._isTestnet,
  });

  @override
  Future<Result<Order, ExchangeFailure>> getOrder(String orderId) =>
      _read((api) => _readOrder(api.orders.getOrderSummary(orderId)));

  @override
  Future<Result<BuyOrder, ExchangeFailure>> refreshBuyOrder(String orderId) =>
      _read((api) => _readOrder(api.orders.refreshOrderSummary(orderId)));

  @override
  Future<Result<SellOrder, ExchangeFailure>> refreshSellOrder(String orderId) =>
      _read((api) => _readOrder(api.orders.refreshOrderSummary(orderId)));

  @override
  Future<Result<FiatPaymentOrder, ExchangeFailure>> refreshPayOrder(
    String orderId,
  ) => _read((api) => _readOrder(api.orders.refreshOrderSummary(orderId)));

  @override
  Future<Result<BuyOrder, ExchangeFailure>> confirmBuyOrder(String orderId) =>
      _write((api) => _readOrder(api.orders.confirmOrderSummary(orderId)));

  @override
  Future<Result<WithdrawOrder, ExchangeFailure>> confirmWithdrawOrder(
    String orderId, {
    ({
      String recipientId,
      String email,
      String? securityQuestion,
      String? securityAnswer,
    })?
    interacUpdate,
  }) => _write((api) async {
    final result = await _readOrder<WithdrawOrder>(
      api.orders.confirmOrderSummary(orderId),
    );
    if (result is Ok<WithdrawOrder, ExchangeFailure> && interacUpdate != null) {
      final update = await api.recipients.updateInteracSecurityDetails(
        recipientId: interacUpdate.recipientId,
        email: interacUpdate.email,
        securityQuestion: interacUpdate.securityQuestion,
        securityAnswer: interacUpdate.securityAnswer,
      );
      if (update case Err()) {
        log.warning(
          'Withdrawal completed without updating Interac security details',
        );
      }
    }
    return result;
  });

  @override
  Future<Result<BuyOrder, ExchangeFailure>> accelerateBuyOrder(
    String orderId,
  ) => _write((api) => _readOrder(api.orders.unbatchAndExpressOrder(orderId)));

  @override
  Future<Result<BuyOrder, ExchangeFailure>> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required BtcNetwork network,
    required bool isOwner,
    String? payjoinBip21,
  }) => _write(
    (api) => _readOrder(
      api.orders.createOrderBuy(
        fiatCurrency: currency.code,
        network: BtcNetworkWire.orderNetwork(network),
        isOwner: isOwner,
        address: payjoinBip21 == null ? toAddress : null,
        bip21URI: payjoinBip21,
        fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
        bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
      ),
      creatingOrder: true,
    ),
  );

  @override
  Future<Result<SellOrder, ExchangeFailure>> placeSellOrder({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required BtcNetwork network,
    bool usePayjoin = false,
  }) => _write(
    (api) => _readOrder(
      api.orders.sellToBalance(
        fiatCurrency: currency.code,
        bitcoinNetwork: BtcNetworkWire.orderNetwork(network),
        usePayjoin: usePayjoin,
        fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
        bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
      ),
      creatingOrder: true,
    ),
  );

  @override
  Future<Result<FiatPaymentOrder, ExchangeFailure>> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required BtcNetwork network,
    String? paymentDescription,
    SepaPaymentProcessor? paymentProcessor,
    bool usePayjoin = false,
  }) => _write(
    (api) => _readOrder(
      api.orders.sellToRecipient(
        recipientId: recipientId,
        paymentProcessor: _sepaPaymentProcessor(paymentProcessor),
        bitcoinNetwork: BtcNetworkWire.orderNetwork(network),
        usePayjoin: usePayjoin,
        fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
        bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
        paymentDescription: paymentDescription?.isNotEmpty == true
            ? paymentDescription
            : null,
      ),
      creatingOrder: true,
    ),
  );

  @override
  Future<Result<WithdrawOrder, ExchangeFailure>> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    SepaPaymentProcessor? paymentProcessor,
    String? securityQuestion,
    String? securityAnswer,
  }) => _write(
    (api) => _readOrder(
      api.orders.createWithdrawalOrder(
        fiatAmount: fiatAmount,
        recipientId: recipientId,
        paymentProcessor: _sepaPaymentProcessor(paymentProcessor),
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
      ),
      creatingOrder: true,
    ),
  );

  @override
  Future<Result<Order?, ExchangeFailure>> getOrderByTxId(String txId) => _read(
    (api) async => switch (await _listOrderSummaries(api, txId: txId)) {
      Ok(:final value) => switch (value.match) {
        final summary? => _mapOrder<Order>(summary),
        null when value.rejected => const Err(ExchangeOrderLoadFailure()),
        null => const Ok(null),
      },
      Err(:final failure) => Err(failure),
    },
  );

  /// History is best-effort: preserve valid entries if one element is malformed.
  @override
  Future<Result<List<Order>, ExchangeFailure>> getOrders({
    int? limit,
    int? offset,
    OrderType? type,
  }) => _read((api) async {
    final List<Order> orders = [];
    switch (await _listOrderSummaries(api)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        for (final summary in value.orders) {
          switch (_mapOrder<Order>(summary)) {
            case Ok(value: final order):
              if (type == null || order.orderType == type) orders.add(order);
            case Err():
              continue;
          }
        }
    }
    if (limit == null && offset == null) return Ok(orders);
    final start = (offset ?? 0).clamp(0, orders.length);
    final end = limit == null
        ? orders.length
        : (start + limit).clamp(start, orders.length);
    return Ok(orders.sublist(start, end));
  });

  @override
  Future<Result<Dca, ExchangeFailure>> createDca({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required BtcNetwork network,
    required String address,
    bool enablePreference = false,
  }) => _write((api) async {
    bbx.UserSummary? summary;
    if (enablePreference) {
      switch (await api.users.getUserSummary()) {
        case Ok(value: final value?):
          summary = value;
        case Ok() || Err():
          return const Err(ExchangeAccountUnavailableFailure());
      }
    }

    switch (await api.orderTriggers.createDca(
      amount: amount,
      currencyCode: currency.code,
      frequency: switch (frequency) {
        DcaBuyFrequency.hourly => bbx.DcaFrequency.hourly,
        DcaBuyFrequency.daily => bbx.DcaFrequency.daily,
        DcaBuyFrequency.weekly => bbx.DcaFrequency.weekly,
        DcaBuyFrequency.monthly => bbx.DcaFrequency.monthly,
      },
      recipientType: BtcNetworkWire.dcaRecipientType(network),
      address: address,
    )) {
      case Err(:final failure):
        return Err(_mapFailure(failure));
      case Ok(value: final dca):
        final amount = double.tryParse(dca.amountStr);
        final currency = switch (ExchangeCatalog.parse(dca.currencyCode)) {
          KnownCurrency(:final currency) => currency,
          UnknownCurrency() => null,
        };
        final nextPurchase = DateTime.tryParse(dca.nextRunAt);
        final frequency = switch (dca.recurringFrequency) {
          'HOURLY' => DcaBuyFrequency.hourly,
          'DAILY' => DcaBuyFrequency.daily,
          'WEEKLY' => DcaBuyFrequency.weekly,
          'MONTHLY' => DcaBuyFrequency.monthly,
          _ => null,
        };
        final network = switch (BtcNetworkWire.parseRecipientType(
          dca.recipientType,
        )) {
          KnownBtcNetwork(:final network) => network,
          UnknownBtcNetwork() => null,
        };
        if (amount == null ||
            currency == null ||
            nextPurchase == null ||
            frequency == null ||
            network == null) {
          return const Err(ExchangeOrderLoadFailure());
        }
        if (summary != null) {
          final preference = await api.users.saveUserPreferences(
            bbx.UserPreferences(
              language: summary.language,
              defaultFiatCurrencyCode: summary.currency,
              dcaEnabled: 'true',
              autoBuyEnabled: summary.autoBuy.isActive.toString(),
              emailNotifications: summary.emailNotificationsEnabled.toString(),
            ),
          );
          if (preference case Err(:final failure)) {
            log.warning(
              'DCA created but enabling the preference failed',
              error: failure.runtimeType,
            );
          }
        }
        return Ok(
          Dca(
            amount: amount,
            currency: currency,
            frequency: frequency,
            network: network,
            address: dca.address,
            nextPurchaseDate: nextPurchase,
          ),
        );
    }
  });

  Future<Result<T, ExchangeFailure>> _readOrder<T extends Order>(
    Future<Result<bbx.OrderSummary, bbx.BbxFailure>> request, {
    bool creatingOrder = false,
  }) async {
    final result = await request;
    if (result
        case Err(
          failure: bbx.BbxRpcFailure(
                :final apiCode,
                :final code,
                :final requestId,
              ) ||
              bbx.BbxOrderLimitFailure(
                :final apiCode,
                :final code,
                :final requestId,
              ) ||
              bbx.BbxConfidentialSepaInactiveFailure(
                :final apiCode,
                :final code,
                :final requestId,
              ),
        )
        when creatingOrder) {
      log.warning(
        'Exchange order creation refused',
        error:
            'apiCode: $apiCode, rpcCode: $code'
            '${requestId == null ? '' : ', requestId=$requestId'}',
      );
    }
    return switch (result) {
      Ok(:final value) => _mapOrder<T>(value),
      Err(failure: bbx.BbxOrderLimitFailure(:final apiCode, :final code))
          when !creatingOrder =>
        Err(ExchangeOrderRejectedFailure(apiCode: apiCode, rpcCode: code)),
      Err(:final failure) => Err(_mapFailure(failure)),
    };
  }

  Result<T, ExchangeFailure> _mapOrder<T extends Order>(
    bbx.OrderSummary summary,
  ) {
    try {
      final order = orderFromBbxApi(summary, isTestnet: _isTestnet);
      if (order is T) return Ok(order);
      return const Err(ExchangeOrderLoadFailure());
    } on FormatException catch (_, trace) {
      log.severe(
        message: 'Error mapping exchange order',
        error: 'FormatException',
        trace: trace,
      );
      return const Err(ExchangeOrderLoadFailure());
    }
  }

  Future<
    Result<
      ({List<bbx.OrderSummary> orders, bbx.OrderSummary? match, bool rejected}),
      ExchangeFailure
    >
  >
  _listOrderSummaries(bbx.Bbx api, {String? txId}) async {
    final orders = <bbx.OrderSummary>[];
    final seen = <String>{};
    var hasRejected = false;
    for (var page = 1; page <= _maximumPages; page++) {
      switch (await api.orders.listOrderSummaries(
        page: page,
        requireElements: true,
      )) {
        case Ok(:final value):
          for (final rejected in value.rejected) {
            log.severe(
              message: 'Error parsing order element',
              error: rejected.runtimeType.toString(),
              trace: StackTrace.current,
            );
          }
          hasRejected = hasRejected || value.rejected.isNotEmpty;
          if (value.rawCount == 0) {
            return Ok((orders: orders, match: null, rejected: hasRejected));
          }
          final previousLength = seen.length;
          for (final summary in value.orders) {
            if (txId != null && orderSummaryMatchesTxId(summary, txId)) {
              return Ok((
                orders: const [],
                match: summary,
                rejected: hasRejected,
              ));
            }
            if (seen.add(summary.orderId) && txId == null) orders.add(summary);
          }
          if (seen.length == previousLength && value.rejected.isEmpty) {
            return const Err(ExchangeOrderLoadFailure());
          }
        case Err(failure: bbx.BbxMissingCredentialFailure()) when page == 1:
          return const Ok((orders: [], match: null, rejected: false));
        case Err(:final failure):
          return Err(switch (_mapFailure(failure)) {
            final ExchangeCredentialReadFailure failure => failure,
            final ExchangeSessionRejectedFailure failure => failure,
            _ => const ExchangeOrderLoadFailure(),
          });
      }
    }
    return const Err(ExchangeOrderLoadFailure());
  }

  static bbx.SepaPaymentProcessor? _sepaPaymentProcessor(
    SepaPaymentProcessor? processor,
  ) => switch (processor) {
    null => null,
    SepaPaymentProcessor.regular => bbx.SepaPaymentProcessor.regular,
    SepaPaymentProcessor.confidential => bbx.SepaPaymentProcessor.confidential,
  };

  static ExchangeFailure _mapFailure(
    bbx.BbxFailure failure,
  ) => switch (failure) {
    bbx.BbxMissingCredentialFailure() =>
      const ExchangeNotAuthenticatedFailure(),
    bbx.BbxCredentialUnavailableFailure() =>
      const ExchangeCredentialReadFailure(),
    bbx.BbxHttpFailure(status: 401) => const ExchangeSessionRejectedFailure(),
    bbx.BbxConfidentialSepaInactiveFailure() =>
      const ExchangeConfidentialSepaInactiveFailure(),
    bbx.BbxOrderLimitFailure(:final bound, :final amount, :final currency) =>
      ExchangeOrderLimitFailure(
        switch (bound) {
          bbx.BbxOrderLimitBound.minimum => ExchangeOrderAmountBound.minimum,
          bbx.BbxOrderLimitBound.maximum => ExchangeOrderAmountBound.maximum,
        },
        amount,
        currency,
      ),
    bbx.BbxRpcFailure(:final apiCode, :final code) =>
      ExchangeOrderRejectedFailure(apiCode: apiCode, rpcCode: code),
    bbx.BbxTimeoutFailure() ||
    bbx.BbxConnectionFailure() => const ExchangeNetworkFailure(),
    _ => const ExchangeOrderLoadFailure(),
  };
}
