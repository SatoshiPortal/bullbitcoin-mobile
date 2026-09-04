import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class CreateWithdrawOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  CreateWithdrawOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<WithdrawOrder, WithdrawFailure>> execute({
    required double fiatAmount,
    required String recipientId,
    required RecipientType recipientType,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final isETransfer = recipientType == RecipientType.interacEmailCad;
      final order = await repo.placeWithdrawalOrder(
        fiatAmount: fiatAmount,
        recipientId: recipientId,
        isETransfer: isETransfer,
      );

      return Ok(order);
    } on ApiKeyException catch (e, st) {
      log.severe(
        message: 'Withdrawal order rejected: not authenticated',
        error: e,
        trace: st,
      );
      return Err(WithdrawUnauthenticatedFailure(e.message));
    } on BullBitcoinApiMinAmountException catch (e) {
      // The two amount bounds are expected user input errors, so they are
      // logged at info rather than severe; the bound itself travels in the
      // failure so the screen can name it.
      log.info('Withdrawal order below the minimum: ${e.message}');
      return Err(
        WithdrawBelowMinAmountFailure(
          minAmount: e.minAmount,
          currency: e.currency,
          logMessage: e.message,
        ),
      );
    } on BullBitcoinApiMaxAmountException catch (e) {
      log.info('Withdrawal order above the maximum: ${e.message}');
      return Err(
        WithdrawAboveMaxAmountFailure(
          maxAmount: e.maxAmount,
          currency: e.currency,
          logMessage: e.message,
        ),
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to place the withdrawal order',
        error: e,
        trace: st,
      );
      return Err(WithdrawUnexpectedFailure('$e'));
    }
  }
}
