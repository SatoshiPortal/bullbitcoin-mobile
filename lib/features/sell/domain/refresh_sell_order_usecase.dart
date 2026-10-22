import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/sell_order_payin_x.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class RefreshSellOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  RefreshSellOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
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
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final Order order = isRecipientPayout
          ? await repo.refreshPayOrder(orderId)
          : await repo.refreshSellOrder(orderId);

      // Fail closed: a refreshed order that pays a different address must
      // never be handed back to the payment flow.
      final deposit = validateSellOrderDepositAddress(
        order: order,
        expectedDepositAddress: expectedDepositAddress,
        expectedLightningInvoice: expectedLightningInvoice,
      );
      if (deposit case Err(:final failure)) return Err(failure);

      return Ok(order);
    } on ApiKeyException catch (e) {
      return Err(SellUnauthenticatedFailure(e.message));
    } catch (e, st) {
      log.severe(
        message: 'Failed to refresh the sell order',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
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
  final actual = lightning ? order.sellLightningInvoice : order.toAddress;
  if (expected == null || expected.isEmpty || actual != expected) {
    return const Err(
      SellDepositAddressChangedFailure(
        'refreshed order deposit address does not match the confirmed one',
      ),
    );
  }
  return const Ok(null);
}
