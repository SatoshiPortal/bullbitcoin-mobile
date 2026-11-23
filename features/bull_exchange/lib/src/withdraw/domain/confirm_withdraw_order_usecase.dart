import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/withdraw/domain/map_withdraw_order_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class ConfirmWithdrawOrderUsecase {
  final Exchange _exchange;
  final Preferences _settingsRepository;

  ConfirmWithdrawOrderUsecase({
    required this._exchange,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<WithdrawOrder, WithdrawFailure>> execute({
    required String orderId,
    InteracSecurityDetails? interacSecurityDetails,
    bool saveSecurityDetailsAsDefault = false,
  }) async {
    bool? isTestnetEnvironment;
    ExchangeOrders? repository;
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
      final environment = settings.environment.networkEnv;
      final exchangeNetwork = switch (environment) {
        NetworkEnv.mainnet => BitcoinNetwork.mainnet,
        NetworkEnv.testnet => BitcoinNetwork.testnet,
        NetworkEnv.regtest => BitcoinNetwork.regtest,
        NetworkEnv.signet => BitcoinNetwork.signet,
      };
      if (!NetworkCapabilities.supports(
        exchangeNetwork,
        NetworkCapability.exchange,
      )) {
        log.warning('Capability refused feature=withdraw reason=unsupported');
        return const Err(WithdrawUnsupportedNetworkFailure());
      }
      final isTestnet = environment == NetworkEnv.testnet;
      isTestnetEnvironment = isTestnet;
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      repository = repo;
      final details = interacSecurityDetails;
      final result = await repo.confirmWithdrawOrder(
        orderId,
        interacUpdate: details == null
            ? null
            : (
                recipientId: details.recipientId,
                email: details.email,
                securityQuestion: saveSecurityDetailsAsDefault
                    ? details.securityQuestion
                    : null,
                securityAnswer: saveSecurityDetailsAsDefault
                    ? details.securityAnswer
                    : null,
              ),
      );
      switch (result) {
        case Ok(:final value):
          return Ok(value);
        case Err(:final failure):
          final mapped = mapWithdrawOrderFailure(failure);
          if (mapped is! WithdrawUnexpectedFailure) return Err(mapped);
          // The request may have reached the server and confirmed the order:
          // the order itself says whether it did, never a retry.
          return _confirmedAfterUnknownOutcome(
            repo,
            orderId: orderId,
            interacSecurityDetails: interacSecurityDetails,
            saveSecurityDetailsAsDefault: saveSecurityDetailsAsDefault,
            isTestnet: isTestnet,
          );
      }
    } on Exception catch (_, st) {
      // The raw error is deliberately dropped, as for order creation: it must
      // not carry order payment data into diagnostics.
      log.severe(
        message: 'Failed to confirm the withdrawal order',
        error: 'Unexpected withdrawal confirmation failure',
        trace: st,
      );
      final repo = repository;
      final isTestnet = isTestnetEnvironment;
      if (repo == null || isTestnet == null) {
        // Nothing was sent: the failure came before the request.
        return const Err(
          WithdrawUnexpectedFailure('Failed to confirm the withdrawal order'),
        );
      }
      return _confirmedAfterUnknownOutcome(
        repo,
        orderId: orderId,
        interacSecurityDetails: interacSecurityDetails,
        saveSecurityDetailsAsDefault: saveSecurityDetailsAsDefault,
        isTestnet: isTestnet,
      );
    }
  }

  /// Re-reads the order after a confirmation whose outcome is unknown. Ok when
  /// the order is confirmed, [WithdrawUnexpectedFailure] when it is still
  /// awaiting confirmation (or ended without being withdrawn), so Confirm can
  /// be offered again, and [WithdrawConfirmOutcomeUnknownFailure] when the
  /// order cannot tell.
  @useResult
  Future<Result<WithdrawOrder, WithdrawFailure>> checkConfirmation({
    required String orderId,
    InteracSecurityDetails? interacSecurityDetails,
    bool saveSecurityDetailsAsDefault = false,
  }) async {
    final bool isTestnet;
    try {
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          isTestnet = value.environment.networkEnv == NetworkEnv.testnet;
        case Err():
          return const Err(WithdrawConfirmOutcomeUnknownFailure('settings'));
      }
    } on Exception catch (_, st) {
      log.warning(
        'Could not read settings to check the withdrawal confirmation',
        trace: st,
      );
      return const Err(WithdrawConfirmOutcomeUnknownFailure('settings'));
    }
    return _confirmedAfterUnknownOutcome(
      _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      ),
      orderId: orderId,
      interacSecurityDetails: interacSecurityDetails,
      saveSecurityDetailsAsDefault: saveSecurityDetailsAsDefault,
      isTestnet: isTestnet,
    );
  }

  Future<Result<WithdrawOrder, WithdrawFailure>> _confirmedAfterUnknownOutcome(
    ExchangeOrders repository, {
    required String orderId,
    required InteracSecurityDetails? interacSecurityDetails,
    required bool saveSecurityDetailsAsDefault,
    required bool isTestnet,
  }) async {
    final Order order;
    try {
      switch (await repository.getOrder(orderId)) {
        case Ok(:final value):
          order = value;
        case Err(:final failure):
          log.warning(
            'Could not re-read the withdrawal order after an unknown '
            'confirmation: ${failure.runtimeType}',
          );
          return const Err(
            WithdrawConfirmOutcomeUnknownFailure('re-read failed'),
          );
      }
    } on Exception catch (_, st) {
      log.warning(
        'Could not re-read the withdrawal order after an unknown confirmation',
        trace: st,
      );
      return const Err(WithdrawConfirmOutcomeUnknownFailure('re-read failed'));
    }
    if (order is! WithdrawOrder) {
      log.severe(
        error: 'Re-read withdrawal order has type ${order.runtimeType}',
        trace: StackTrace.current,
      );
      return const Err(WithdrawConfirmOutcomeUnknownFailure('order type'));
    }
    switch (order.orderStatus) {
      case OrderStatus.inProgress || OrderStatus.completed:
        log.warning(
          'Withdrawal confirmation failed but the order is confirmed; '
          'reporting success',
        );
        await _updateInteracSecurityDetails(
          interacSecurityDetails,
          saveAsDefault: saveSecurityDetailsAsDefault,
          isTestnet: isTestnet,
        );
        return Ok(order);
      case OrderStatus.awaitingConfirmation ||
          OrderStatus.canceled ||
          OrderStatus.expired ||
          OrderStatus.orderExpired ||
          OrderStatus.rejected ||
          OrderStatus.failed:
        return Err(
          WithdrawUnexpectedFailure(
            'confirmation failed; order is ${order.orderStatus.name}',
          ),
        );
      case OrderStatus.unknown:
        return const Err(WithdrawConfirmOutcomeUnknownFailure('order status'));
    }
  }

  /// The confirm call saves the details itself on success; a confirmation
  /// only recovered by the re-read saves them here.
  Future<void> _updateInteracSecurityDetails(
    InteracSecurityDetails? details, {
    required bool saveAsDefault,
    required bool isTestnet,
  }) async {
    if (details == null) return;
    try {
      final result = await _exchange.recipients.updateInteracSecurityDetails(
        recipientId: details.recipientId,
        email: details.email,
        securityQuestion: saveAsDefault ? details.securityQuestion : null,
        securityAnswer: saveAsDefault ? details.securityAnswer : null,
        isTestnet: isTestnet,
      );
      if (result case Err()) {
        log.warning(
          'Withdrawal completed without updating Interac security details',
        );
      }
    } on Exception {
      log.warning(
        'Withdrawal completed without updating Interac security details',
      );
    }
  }
}
