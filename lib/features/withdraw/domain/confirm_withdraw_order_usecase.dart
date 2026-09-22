import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bull_logger/bull_logger.dart';

class ConfirmWithdrawOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  ConfirmWithdrawOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

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
    } on WithdrawError catch (e) {
      return Err(_mapLegacyWithdrawError(e));
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to confirm withdrawal order',
        error: error,
        trace: stackTrace,
      );
      return Err(WithdrawUnexpectedFailure('$error'));
    }
  }
}

WithdrawFailure _mapLegacyWithdrawError(WithdrawError error) => switch (error) {
  UnauthenticatedWithdrawError() => const WithdrawUnauthenticatedFailure(),
  BelowMinAmountWithdrawError(:final minAmount, :final currency) =>
    WithdrawBelowMinAmountFailure(minAmount: minAmount, currency: currency),
  AboveMaxAmountWithdrawError(:final maxAmount, :final currency) =>
    WithdrawAboveMaxAmountFailure(maxAmount: maxAmount, currency: currency),
  OrderNotFoundWithdrawError() => const WithdrawOrderNotFoundFailure(),
  OrderAlreadyConfirmedWithdrawError() =>
    const WithdrawOrderAlreadyConfirmedFailure(),
  UnexpectedWithdrawError(:final message) => WithdrawUnexpectedFailure(message),
};
