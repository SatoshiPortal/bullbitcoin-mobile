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
      final repo = _exchange.orders(
        isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet,
      );
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
      return result.mapErr(mapWithdrawOrderFailure);
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
  }
}
