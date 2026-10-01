import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

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

  @useResult
  Future<Result<WithdrawOrder, WithdrawFailure>> execute({
    required String orderId,
    InteracSecurityDetails? interacSecurityDetails,
    bool saveSecurityDetailsAsDefault = false,
  }) async {
    final WithdrawOrder order;
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      order = await repo.confirmWithdrawOrder(orderId);
    } on ApiKeyException catch (e, st) {
      log.severe(
        message: 'Cannot confirm the withdrawal order: not authenticated',
        error: e,
        trace: st,
      );
      return Err(WithdrawUnauthenticatedFailure(e.message));
    } catch (_, st) {
      // The raw error is deliberately dropped, as for order creation: it must
      // not carry order payment data into diagnostics.
      log.severe(
        message: 'Failed to confirm the withdrawal order',
        error: 'Unexpected withdrawal confirmation failure',
        trace: st,
      );
      return const Err(
        WithdrawUnexpectedFailure('Failed to confirm the withdrawal order'),
      );
    }

    // The withdrawal is already confirmed at this point, so failing to save
    // the recipient's Interac details must not turn it into a failure.
    await _updateInteracSecurityDetails(
      interacSecurityDetails,
      saveAsDefault: saveSecurityDetailsAsDefault,
    );
    return Ok(order);
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
