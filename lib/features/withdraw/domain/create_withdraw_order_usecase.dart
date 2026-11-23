import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/withdraw/domain/map_withdraw_order_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
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
  final Exchange _exchange;
  final Preferences _settingsRepository;

  CreateWithdrawOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<CreateWithdrawOrderResult, WithdrawFailure>> execute({
    required double fiatAmount,
    required String recipientId,
    RecipientType? recipientType,
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
      final SettingsEntity settings;
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(
            WithdrawUnexpectedFailure('Preferences read failed'),
          );
      }
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.environment.name),
        NetworkCapability.exchange,
      )) {
        log.warning('Capability refused feature=withdraw reason=unsupported');
        return const Err(WithdrawUnsupportedNetworkFailure());
      }
      final isTestnet = settings.environment.requireHistoricalTestnet();
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      final WithdrawOrder order;
      switch (await repo.placeWithdrawalOrder(
        fiatAmount: fiatAmount,
        recipientId: recipientId,
        paymentProcessor: switch (recipientType) {
          RecipientType.sepaEur => SepaPaymentProcessor.regular,
          RecipientType.confidentialSepaEur =>
            SepaPaymentProcessor.confidential,
          _ => null,
        },
        securityQuestion: interacSecurityDetails?.securityQuestion,
        securityAnswer: interacSecurityDetails?.securityAnswer,
      )) {
        case Ok(:final value):
          order = value;
        case Err(:final failure):
          return Err(mapWithdrawOrderFailure(failure));
      }

      return Ok(
        CreateWithdrawOrderResult(
          order: order,
          interacSecurityDetails: interacSecurityDetails,
        ),
      );
    } on Exception catch (_, st) {
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
