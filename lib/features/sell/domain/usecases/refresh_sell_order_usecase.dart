import 'package:bb_mobile/features/sell/domain/map_sell_order_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/sell_order_payin_x.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class RefreshSellOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;

  RefreshSellOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<Order, SellFailure>> execute({
    required String orderId,
    required String? expectedDepositAddress,
    String? expectedLightningInvoice,
    bool isRecipientPayout = false,
  }) async {
    try {
      final SettingsEntity settings;
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(SellUnexpectedFailure('Preferences read failed'));
      }
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.environment.name),
        NetworkCapability.exchange,
      )) {
        return const Err(SellUnsupportedNetworkFailure());
      }
      final isTestnet = settings.environment.requireHistoricalTestnet();
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      final Order order;
      switch (isRecipientPayout
          ? await repo.refreshPayOrder(orderId)
          : await repo.refreshSellOrder(orderId)) {
        case Ok(:final value):
          order = value;
        case Err(:final failure):
          return Err(mapSellOrderFailure(failure));
      }

      // Fail closed: a refreshed order that pays a different address must
      // never be handed back to the payment flow.
      final deposit = validateSellOrderDepositAddress(
        order: order,
        expectedDepositAddress: expectedDepositAddress,
        expectedLightningInvoice: expectedLightningInvoice,
      );
      if (deposit case Err(:final failure)) return Err(failure);

      return Ok(order);
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to refresh the sell order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(SellUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}

@useResult
Result<void, SellFailure> validateSellOrderDepositAddress({
  required Order order,
  required String? expectedDepositAddress,
  String? expectedLightningInvoice,
}) {
  final lightning = order.payinMethod == OrderPaymentMethod.lnInvoice;
  final expected = lightning
      ? expectedLightningInvoice
      : expectedDepositAddress;
  final actual = lightning
      ? order.sellLightningInvoice
      : order.sellPayinAddress;
  if (expected == null || expected.isEmpty || actual != expected) {
    return const Err(
      SellDepositAddressChangedFailure(
        'refreshed order deposit address does not match the confirmed one',
      ),
    );
  }
  return const Ok(null);
}
