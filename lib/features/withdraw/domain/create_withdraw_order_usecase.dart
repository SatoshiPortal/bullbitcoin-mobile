import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

final class CreateWithdrawOrderResult {
  final WithdrawOrder order;
  final InteracSecurityDetails? interacSecurityDetails;

  const CreateWithdrawOrderResult({
    required this.order,
    required this.interacSecurityDetails,
  });
}

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
  Future<Result<CreateWithdrawOrderResult, WithdrawFailure>> execute({
    required double fiatAmount,
    required String recipientId,
    String? recipientEmail,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    final InteracSecurityDetails? interacSecurityDetails;
    switch (_validateInteracSecurityDetails(
      recipientId: recipientId,
      recipientEmail: recipientEmail,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    )) {
      case Ok(:final value):
        interacSecurityDetails = value;
      case Err(:final failure):
        return Err(failure);
    }

    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final order = await repo.placeWithdrawalOrder(
        fiatAmount: fiatAmount,
        recipientId: recipientId,
        securityQuestion: interacSecurityDetails?.securityQuestion,
        securityAnswer: interacSecurityDetails?.securityAnswer,
      );

      return Ok(
        CreateWithdrawOrderResult(
          order: order,
          interacSecurityDetails: interacSecurityDetails,
        ),
      );
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
    } catch (_, st) {
      // The raw error is deliberately dropped: the request can carry the
      // Interac security answer, which must never reach diagnostics.
      log.severe(
        message: 'Failed to place the withdrawal order',
        error: 'Unexpected withdrawal creation failure',
        trace: st,
      );
      return const Err(
        WithdrawUnexpectedFailure('Failed to place the withdrawal order'),
      );
    }
  }

  @useResult
  Result<InteracSecurityDetails?, WithdrawFailure>
  _validateInteracSecurityDetails({
    required String recipientId,
    required String? recipientEmail,
    required String? securityQuestion,
    required String? securityAnswer,
  }) {
    const invalid = Err<InteracSecurityDetails?, WithdrawFailure>(
      WithdrawUnexpectedFailure('Invalid Interac security details'),
    );
    final hasSecurityDetails =
        securityQuestion != null || securityAnswer != null;
    if (recipientEmail == null) {
      return hasSecurityDetails ? invalid : const Ok(null);
    }

    final result = InteracSecurityDetails.create(
      recipientId: recipientId,
      email: recipientEmail,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    );
    return switch (result) {
      Ok(:final value)
          when value.securityQuestion != null && value.securityAnswer != null =>
        Ok(value),
      _ => invalid,
    };
  }
}
