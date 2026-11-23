import 'package:bull_exchange/src/pay/domain/map_pay_order_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class RefreshPayOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;

  RefreshPayOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<FiatPaymentOrder, PayFailure>> execute({
    required String orderId,
    required String? expectedDepositAddress,
    String? expectedLightningInvoice,
  }) async {
    try {
      final SettingsEntity settings;
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(PayUnexpectedFailure('Preferences read failed'));
      }
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.environment.name),
        NetworkCapability.exchange,
      )) {
        return const Err(PayUnsupportedNetworkFailure());
      }
      final isTestnet = settings.environment.requireHistoricalTestnet();
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      final FiatPaymentOrder order;
      switch (await repo.refreshPayOrder(orderId)) {
        case Ok(:final value):
          order = value;
        case Err(:final failure):
          return Err(mapPayOrderFailure(failure));
      }

      if (!_refreshKeepsDeposit(
        order: order,
        expectedDepositAddress: expectedDepositAddress,
        expectedLightningInvoice: expectedLightningInvoice,
      )) {
        log.severe(
          error: 'Pay order came back with a different deposit address',
          trace: StackTrace.current,
        );
        return const Err(PayDepositAddressChangedFailure());
      }

      return Ok(order);
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to refresh the pay order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(PayUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}

/// A re-quote keeps an on-chain order's deposit address. A Lightning order's
/// re-quote may carry a new invoice (an invoice fixes its amount), so only its
/// rail is kept: still an invoice, never an on-chain address.
bool _refreshKeepsDeposit({
  required FiatPaymentOrder order,
  required String? expectedDepositAddress,
  required String? expectedLightningInvoice,
}) {
  final isLightningOrder =
      (expectedDepositAddress == null || expectedDepositAddress.isEmpty) &&
      expectedLightningInvoice != null &&
      expectedLightningInvoice.isNotEmpty;
  if (!isLightningOrder) {
    return payOrderDepositAddressMatches(
      order: order,
      expectedDepositAddress: expectedDepositAddress,
    );
  }
  final invoice = order.lightningInvoice;
  return order.toAddress == null && invoice != null && invoice.isNotEmpty;
}

/// Whether [order] still points at the deposit it was created with: the
/// on-chain address, or for a Lightning order (the exchange fills only its
/// `lightningInvoice`, never an address) the invoice.
///
/// A deposit that moves must never happen in correct backend operation, so
/// callers refuse the order rather than pay it. This is a predicate rather than
/// a throwing guard so each caller decides how to surface the refusal.
bool payOrderDepositAddressMatches({
  required FiatPaymentOrder order,
  required String? expectedDepositAddress,
  String? expectedLightningInvoice,
}) {
  if (expectedDepositAddress != null && expectedDepositAddress.isNotEmpty) {
    return order.toAddress == expectedDepositAddress;
  }
  if (expectedLightningInvoice != null && expectedLightningInvoice.isNotEmpty) {
    return order.lightningInvoice == expectedLightningInvoice;
  }
  return false;
}
