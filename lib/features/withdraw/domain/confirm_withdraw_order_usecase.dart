import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/withdraw/domain/map_withdraw_order_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
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
    final WithdrawOrder order;
    final bool isTestnet;
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
      isTestnet = environment == NetworkEnv.testnet;
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
      switch (await repo.confirmWithdrawOrder(orderId)) {
        case Ok(:final value):
          order = value;
        case Err(:final failure):
          return Err(mapWithdrawOrderFailure(failure));
      }
    } on Exception catch (_, st) {
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
      isTestnet: isTestnet,
    );
    return Ok(order);
  }

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
