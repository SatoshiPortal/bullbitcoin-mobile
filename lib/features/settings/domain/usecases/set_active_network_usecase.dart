import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The developer-network selector uses this authorization and persistence boundary.
class SetActiveNetworkUsecase {
  final SettingsRepository _settingsRepository;

  const SetActiveNetworkUsecase({required this._settingsRepository});

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
      try {
        final settings = await _settingsRepository.fetch();
        if (settings.isSuperuser != true || settings.isDevModeEnabled != true) {
          log.warning(
            'Network selection refused network=${network.name} category=developerMode',
          );
          return const Err(SettingsConsentFailure());
        }
      } on Exception catch (error) {
        log.warning(
          'Network selection refused category=settingsRead failure=${error.runtimeType}',
        );
        return const Err(SettingsStorageFailure());
      }
    }
    final result = await _settingsRepository.setEnvironment(environment);
    return result.fold(
      (_) {
        log.config('Active network saved network=${network.name}');
        return const Ok(null);
      },
      (_) {
        log.warning('Network selection refused category=settingsWrite');
        return const Err(SettingsStorageFailure());
      },
    );
  }
}
