import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/generic_extensions.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/dca.dart';
import '../domain/entities/order.dart';
import '../domain/entities/sepa_payment_processor.dart';
import '../domain/exchange_failure.dart';
import '../domain/exchange_orders.dart';
import 'bbx_api_order_mapper.dart';

typedef RunOrderOperation = Future<Result<T, ExchangeFailure>> Function<T>(
  Future<Result<T, ExchangeFailure>> Function(bbx.Bbx),
);

final class BbxApiOrderRepository implements ExchangeOrders {
  final RunOrderOperation _run;
  final bool _isTestnet;

  BbxApiOrderRepository({required this._run, required this._isTestnet});

  @override
  Future<Result<Order, ExchangeFailure>> getOrder(String orderId) =>
      _run((api) => _readOrder(api.orders.getOrderSummary(orderId)));

  @override
  Future<Result<BuyOrder, ExchangeFailure>> refreshBuyOrder(String orderId) =>
      _run((api) => _readOrder(api.orders.refreshOrderSummary(orderId)));

  @override
  Future<Result<SellOrder, ExchangeFailure>> refreshSellOrder(String orderId) =>
      _run((api) => _readOrder(api.orders.refreshOrderSummary(orderId)));

  @override
  Future<Result<FiatPaymentOrder, ExchangeFailure>> refreshPayOrder(
    String orderId,
  ) => _run((api) => _readOrder(api.orders.refreshOrderSummary(orderId)));

  @override
  Future<Result<BuyOrder, ExchangeFailure>> confirmBuyOrder(String orderId) =>
      _run((api) => _readOrder(api.orders.confirmOrderSummary(orderId)));

  @override
  Future<Result<WithdrawOrder, ExchangeFailure>> confirmWithdrawOrder(
    String orderId,
  ) => _run((api) => _readOrder(api.orders.confirmOrderSummary(orderId)));

  @override
  Future<Result<BuyOrder, ExchangeFailure>> accelerateBuyOrder(
    String orderId,
  ) => _run((api) => _readOrder(api.orders.unbatchAndExpressOrder(orderId)));

  @override
  Future<Result<BuyOrder, ExchangeFailure>> placeBuyOrder({
    required String toAddress,
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    required bool isOwner,
    String? payjoinBip21,
  }) => _run(
    (api) => _readOrder(
      api.orders.createOrderBuy(
        fiatCurrency: currency.code,
        network: network.value,
        isOwner: isOwner,
        address: payjoinBip21 == null ? toAddress : null,
        bip21URI: payjoinBip21,
        fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
        bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
      ),
      reportCreationLimits: true,
    ),
  );

  @override
  Future<Result<SellOrder, ExchangeFailure>> placeSellOrder({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required OrderBitcoinNetwork network,
    bool usePayjoin = false,
  }) => _run(
    (api) => _readOrder(
      api.orders.sellToBalance(
        fiatCurrency: currency.code,
        bitcoinNetwork: network.value,
        usePayjoin: usePayjoin,
        fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
        bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
      ),
      reportCreationLimits: true,
    ),
  );

  @override
  Future<Result<FiatPaymentOrder, ExchangeFailure>> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required OrderBitcoinNetwork network,
    String? paymentDescription,
    SepaPaymentProcessor? paymentProcessor,
    bool usePayjoin = false,
  }) => _run(
    (api) => _readOrder(
      api.orders.sellToRecipient(
        recipientId: recipientId,
        paymentProcessor: _sepaPaymentProcessor(paymentProcessor),
        bitcoinNetwork: network.value,
        usePayjoin: usePayjoin,
        fiatAmount: orderAmount.isFiat ? orderAmount.amount : null,
        bitcoinAmount: orderAmount.isBitcoin ? orderAmount.amount : null,
        paymentDescription: paymentDescription?.isNotEmpty == true
            ? paymentDescription
            : null,
      ),
      reportCreationLimits: true,
    ),
  );

  @override
  Future<Result<WithdrawOrder, ExchangeFailure>> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    SepaPaymentProcessor? paymentProcessor,
    String? securityQuestion,
    String? securityAnswer,
  }) => _run(
    (api) => _readOrder(
      api.orders.createWithdrawalOrder(
        fiatAmount: fiatAmount,
        recipientId: recipientId,
        paymentProcessor: _sepaPaymentProcessor(paymentProcessor),
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
      ),
      reportCreationLimits: true,
    ),
  );

  @override
  Future<Result<Order?, ExchangeFailure>> getOrderByTxId(String txId) => _run(
    (api) async => switch (await _listOrderSummaries(api)) {
      Ok(:final value) => switch (value.firstWhereOrNull(
        (s) => orderSummaryMatchesTxId(s, txId),
      )) {
        final summary? => _mapOrder<Order>(summary),
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
  }) => _run((api) async {
    final List<Order> orders = [];
    switch (await _listOrderSummaries(api)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        for (final summary in value) {
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
    required DcaNetwork network,
    required String address,
  }) => _run((api) async {
    switch (await api.orderTriggers.createDca(
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
    )) {
      case Err(:final failure):
        return Err(_mapFailure(failure));
      case Ok(value: final dca):
        final amount = double.tryParse(dca.amountStr);
        final currency = FiatCurrency.tryFromCode(dca.currencyCode);
        final nextPurchase = DateTime.tryParse(dca.nextRunAt);
        final frequency = switch (dca.recurringFrequency) {
          'HOURLY' => DcaBuyFrequency.hourly,
          'DAILY' => DcaBuyFrequency.daily,
          'WEEKLY' => DcaBuyFrequency.weekly,
          'MONTHLY' => DcaBuyFrequency.monthly,
          _ => null,
        };
        final network = switch (dca.recipientType) {
          'OUT_BITCOIN_ADDRESS' => DcaNetwork.bitcoin,
          'OUT_LIGHTNING_ADDRESS' => DcaNetwork.lightning,
          'OUT_LIQUID_ADDRESS' => DcaNetwork.liquid,
          _ => null,
        };
        if (amount == null ||
            currency == null ||
            nextPurchase == null ||
            frequency == null ||
            network == null) {
          return const Err(ExchangeOrderLoadFailure());
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
    bool reportCreationLimits = false,
  }) async => switch (await request) {
    Ok(:final value) => _mapOrder<T>(value),
    Err(failure: bbx.BbxOrderLimitFailure(:final apiCode, :final code))
        when !reportCreationLimits =>
      Err(ExchangeOrderRejectedFailure(apiCode: apiCode, rpcCode: code)),
    Err(:final failure) => Err(_mapFailure(failure)),
  };

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

  Future<Result<List<bbx.OrderSummary>, ExchangeFailure>> _listOrderSummaries(
    bbx.Bbx api,
  ) async {
    switch (await api.orders.listOrderSummaries()) {
      case Ok(:final value):
        for (final rejected in value.rejected) {
          log.severe(
            message: 'Error parsing order element',
            error: rejected.runtimeType.toString(),
            trace: StackTrace.current,
          );
        }
        return Ok(value.orders);
      case Err(failure: bbx.BbxMissingCredentialFailure()):
        return const Ok([]);
      case Err(:final failure):
        return Err(switch (_mapFailure(failure)) {
          final ExchangeCredentialReadFailure failure => failure,
          final ExchangeSessionRejectedFailure failure => failure,
          _ => const ExchangeOrderLoadFailure(),
        });
    }
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
