import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bull_logger/bull_logger.dart';

final class CreateWithdrawOrderResult {
  const CreateWithdrawOrderResult({
    required this.order,
    required this.interacSecurityDetails,
  });

  final WithdrawOrder order;
  final InteracSecurityDetails? interacSecurityDetails;
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

  Future<CreateWithdrawOrderResult> execute({
    required double fiatAmount,
    required String recipientId,
    String? recipientEmail,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    try {
      final interacSecurityDetails = _validateInteracSecurityDetails(
        recipientId: recipientId,
        recipientEmail: recipientEmail,
        securityQuestion: securityQuestion,
        securityAnswer: securityAnswer,
      );

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
      return CreateWithdrawOrderResult(
        order: order,
        interacSecurityDetails: interacSecurityDetails,
      );
    } on WithdrawError {
      rethrow;
    } catch (_) {
      log.severe(
        message: 'Failed to create withdrawal order',
        error: 'Unexpected withdrawal creation failure',
        trace: StackTrace.current,
      );
      throw const WithdrawError.unexpected(
        message: 'Failed to create withdrawal order',
      );
    }
  }

  InteracSecurityDetails? _validateInteracSecurityDetails({
    required String recipientId,
    required String? recipientEmail,
    required String? securityQuestion,
    required String? securityAnswer,
  }) {
    final hasSecurityDetails =
        securityQuestion != null || securityAnswer != null;
    if (recipientEmail == null) {
      if (hasSecurityDetails) _throwInvalidSecurityDetails();
      return null;
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
        value,
      _ => _throwInvalidSecurityDetails(),
    };
  }

  Never _throwInvalidSecurityDetails() {
    throw const WithdrawError.unexpected(
      message: 'Invalid Interac security details',
    );
  }
}
