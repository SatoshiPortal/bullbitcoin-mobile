import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/sepa_payment_processor.dart';
import 'package:bb_mobile/core/exchange/domain/errors/confidential_sepa_not_activated_exception.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bull_logger/bull_logger.dart';

class CreateWithdrawOrderUsecase {
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  CreateWithdrawOrderUsecase({
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
    required this._settingsRepository,
  });

  Future<Result<WithdrawOrder, WithdrawFailure>> execute({
    required double fiatAmount,
    required String recipientId,
    required RecipientType recipientType,
    String? paymentDescription,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;
      final isETransfer = recipientType == RecipientType.interacEmailCad;
      final paymentProcessor = _paymentProcessor(recipientType);
      final order = await repo.placeWithdrawalOrder(
        fiatAmount: fiatAmount,
        recipientId: recipientId,
        paymentProcessor: paymentProcessor,
        paymentDescription: paymentDescription,
        isETransfer: isETransfer,
      );
      return Ok(order);
    } on ConfidentialSepaNotActivatedException catch (e) {
      log.info('Confidential SEPA recipient is not active: ${e.message}');
      return Err(WithdrawConfidentialSepaNotActivatedFailure(e.message));
    } on WithdrawError catch (e) {
      return Err(_mapLegacyWithdrawError(e));
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Failed to create withdrawal order',
        error: error,
        trace: stackTrace,
      );
      return Err(WithdrawUnexpectedFailure('$error'));
    }
  }

  SepaPaymentProcessor? _paymentProcessor(RecipientType type) => switch (type) {
    RecipientType.confidentialSepaEur => SepaPaymentProcessor.confidential,
    RecipientType.sepaEur => SepaPaymentProcessor.regular,
    _ => null,
  };
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
