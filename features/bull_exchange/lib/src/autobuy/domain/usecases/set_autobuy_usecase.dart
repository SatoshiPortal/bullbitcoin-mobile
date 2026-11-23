import 'package:exchange/exchange.dart';

import 'get_autobuy_status_usecase.dart';

import 'package:preferences/preferences.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SetAutoBuyUsecase {
  final Preferences _settingsRepository;
  final Exchange _exchange;

  const SetAutoBuyUsecase(this._settingsRepository, this._exchange);

  @useResult
  Future<Result<void, AutoBuyFailure>> execute({required bool enabled}) async {
    final ExchangeEnvironment environment;
    try {
      final SettingsEntity settings;
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(
            AutoBuyUnexpectedFailure('Exchange preferences unavailable'),
          );
      }
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.activeNetwork.name),
        NetworkCapability.exchange,
      )) {
        return const Err(AutoBuyUnsupportedNetworkFailure());
      }
      environment = settings.environment.requireHistoricalTestnet()
          ? ExchangeEnvironment.testnet
          : ExchangeEnvironment.mainnet;
    } on Exception catch (e, st) {
      // Type only, like every other boundary in this migration.
      log.severe(
        message: 'Failed to read settings before updating AutoBuy',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        AutoBuyUnexpectedFailure('settings fetch failed: ${e.runtimeType}'),
      );
    }

    if (enabled) {
      switch (await _exchange.getDefaultWallets()) {
        case Ok(value: final wallets) when !wallets.hasAnyWallet:
          return const Err(AutoBuyWalletRequiredFailure());
        case Ok():
          break;
        case Err(failure: ExchangeUnsupportedNetworkFailure()):
          return const Err(AutoBuyUnsupportedNetworkFailure());
        case Err(
          failure: ExchangeNotAuthenticatedFailure() ||
              ExchangeSessionRejectedFailure() ||
              ExchangeApiKeyStorageFailure() ||
              ExchangeCredentialReadFailure(),
        ):
          return const Err(AutoBuyAccountUnavailableFailure());
        case Err(:final failure):
          return Err(AutoBuyUnexpectedFailure(failure.logMessage));
      }
    }

    final UserSummary summary;
    switch (await _exchange.getUserSummary(environment)) {
      case Ok(:final value):
        summary = value;
      case Err(:final failure):
        return Err(autoBuySummaryFailure(failure));
    }

    if (enabled && summary.isFundingRestricted) {
      return const Err(AutoBuyFundingRestrictedFailure());
    }

    final saved = await _exchange.saveUserPreference(
      environment,
      language: summary.language,
      currency: summary.currency,
      dcaEnabled: summary.dca.isActive,
      autoBuyEnabled: enabled.toString(),
      emailNotificationsEnabled: summary.emailNotificationsEnabled,
    );
    // The repository is the boundary and has already logged the raw reason.
    if (saved case Err(:final failure)) {
      return Err(AutoBuyPreferenceUpdateFailure(failure.logMessage));
    }

    return const Ok(null);
  }
}
