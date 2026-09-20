import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bull_logger/bull_logger.dart';

class ConfirmWithdrawOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;
  final RecipientsFacade _recipientsFacade;

  ConfirmWithdrawOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
    required this._recipientsFacade,
  });

  Future<WithdrawOrder> execute({
    required String orderId,
    InteracSecurityDetails? interacSecurityDetails,
    bool saveSecurityDetailsAsDefault = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final order = await repo.confirmWithdrawOrder(orderId);
      await _updateInteracSecurityDetails(
        interacSecurityDetails,
        saveAsDefault: saveSecurityDetailsAsDefault,
      );
      return order;
    } on WithdrawError {
      rethrow;
    } catch (_) {
      log.severe(
        message: 'Failed to confirm withdrawal order',
        error: 'Unexpected withdrawal confirmation failure',
        trace: StackTrace.current,
      );
      throw const WithdrawError.unexpected(
        message: 'Failed to confirm withdrawal order',
      );
    }
  }

  Future<void> _updateInteracSecurityDetails(
    InteracSecurityDetails? details, {
    required bool saveAsDefault,
  }) async {
    if (details == null) return;
    try {
      final result = await _recipientsFacade.updateInteracSecurityDetails(
        recipientId: details.recipientId,
        email: details.email,
        securityQuestion: saveAsDefault ? details.securityQuestion : null,
        securityAnswer: saveAsDefault ? details.securityAnswer : null,
      );
      if (result case Err()) {
        log.warning(
          'Withdrawal completed without updating Interac security details',
        );
      }
    } catch (_) {
      log.warning(
        'Withdrawal completed without updating Interac security details',
      );
    }
  }
}
