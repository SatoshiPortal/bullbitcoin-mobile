import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class RefreshPayOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  RefreshPayOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<FiatPaymentOrder, PayFailure>> execute({
    required String orderId,
    required String? expectedDepositAddress,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final order = await repo.refreshPayOrder(orderId);

      if (!payOrderDepositAddressMatches(
        order: order,
        expectedDepositAddress: expectedDepositAddress,
      )) {
        log.severe(
          error:
              'Pay order $orderId came back with a different deposit address',
          trace: StackTrace.current,
        );
        return const Err(PayDepositAddressChangedFailure());
      }

      return Ok(order);
    } on ApiKeyException catch (e, st) {
      log.severe(
        message: 'Pay order refresh rejected: not authenticated',
        error: e,
        trace: st,
      );
      return Err(PayUnauthenticatedFailure(e.message));
    } catch (e, st) {
      log.severe(
        message: 'Failed to refresh the pay order',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}

/// Whether [order] still points at the deposit address it was created with.
///
/// A price-lock refresh that moves the address must never happen in correct
/// backend operation, so callers refuse the order rather than pay it. This is a
/// predicate rather than a throwing guard so each caller decides how to surface
/// the refusal.
bool payOrderDepositAddressMatches({
  required FiatPaymentOrder order,
  required String? expectedDepositAddress,
}) {
  if (expectedDepositAddress == null || expectedDepositAddress.isEmpty) {
    return false;
  }
  return order.toAddress == expectedDepositAddress;
}
