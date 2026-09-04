import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class ConfirmWithdrawOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  ConfirmWithdrawOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<WithdrawOrder, WithdrawFailure>> execute({
    required String orderId,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final order = await repo.confirmWithdrawOrder(orderId);

      return Ok(order);
    } on ApiKeyException catch (e, st) {
      log.severe(
        message: 'Cannot confirm the withdrawal order: not authenticated',
        error: e,
        trace: st,
      );
      return Err(WithdrawUnauthenticatedFailure(e.message));
    } catch (e, st) {
      log.severe(
        message: 'Failed to confirm the withdrawal order',
        error: e,
        trace: st,
      );
      return Err(WithdrawUnexpectedFailure('$e'));
    }
  }
}
