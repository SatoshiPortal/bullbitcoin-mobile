import 'package:electrum/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The developer-network selector uses this authorization and persistence boundary.
class SetActiveNetworkUsecase {
  final Preferences _settingsRepository;
  final ElectrumDefaultsProvisioner _electrumSettings;

  const SetActiveNetworkUsecase({
    required this._settingsRepository,
    required this._electrumSettings,
  });

  @useResult
  Future<Result<void, SettingsFailure>> execute(NetworkEnv network) async {
    final environment = switch (network) {
      NetworkEnv.mainnet => Environment.mainnet,
      NetworkEnv.testnet => Environment.testnet,
      NetworkEnv.regtest => Environment.regtest,
      NetworkEnv.signet => null,
    };
    if (environment == null) {
      log.warning(
        'Network selection refused network=${network.name} category=notReady',
      );
      return Err(SettingsNetworkUnavailableFailure(network));
    }
    // Returning to mainnet must remain possible after developer mode is lost.
    if (network != NetworkEnv.mainnet) {
      switch (await _settingsRepository.fetch()) {
        case Err():
          log.warning('Network selection refused category=settingsRead');
          return const Err(SettingsStorageFailure());
        case Ok(:final value):
          if (value.isSuperuser != true || value.isDevModeEnabled != true) {
            log.warning(
              'Network selection refused network=${network.name} category=developerMode',
            );
            return const Err(SettingsConsentFailure());
          }
      }
    }

    if (network == NetworkEnv.regtest) {
      if (await _electrumSettings.prepareForegroundStorage(network)
          case Err()) {
        log.warning(
          'Network selection refused network=regtest category=electrumStorage',
        );
        return Err(SettingsNetworkUnavailableFailure(network));
      }
      // Preparation can yield; consent may have been revoked in the meantime.
      switch (await _settingsRepository.fetch()) {
        case Err():
          return const Err(SettingsStorageFailure());
        case Ok(:final value):
          if (value.isSuperuser != true || value.isDevModeEnabled != true) {
            return const Err(SettingsConsentFailure());
          }
      }
    }

    final result = await _settingsRepository.setEnvironment(environment);
    return result.fold(
      (_) {
        log.config('Active network saved network=${network.name}');
        return const Ok(null);
      },
      (_) {
        return const Err(SettingsStorageFailure());
      },
    );
  }
}
