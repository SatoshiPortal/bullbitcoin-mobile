import 'package:primitives/primitives.dart';
import 'package:preferences/preferences.dart';
import 'package:silent/src/domain/entities/sp_backend_config.dart';
import 'package:silent/src/domain/repositories/sp_backend_config_repository.dart';
import 'package:silent/src/domain/silent_failure.dart';

/// Admits SP only for the active network and the exact captured configuration.
/// Missing configuration permits setup, never a live snapshot on its own.
class GetSpFeatureGateUsecase {
  final Preferences _settingsRepository;
  final SpBackendConfigRepository _configRepository;

  GetSpFeatureGateUsecase({
    required this._settingsRepository,
    required this._configRepository,
  });

  Future<bool> execute({
    BitcoinNetwork? network,
    SpBackendConfig? config,
    bool allowUnconfigured = false,
  }) async => (await check(
    network: network,
    config: config,
    allowUnconfigured: allowUnconfigured,
  )).fold((value) => value, (_) => false);

  Future<Result<bool, SilentFailure>> check({
    BitcoinNetwork? network,
    SpBackendConfig? config,
    bool allowUnconfigured = false,
  }) async {
    final settings = (await _settingsRepository.fetch()).fold(
      (value) => value,
      (_) => null,
    );
    if (settings == null) {
      return const Err(SilentUnexpected('Silent preferences read failed'));
    }
    final active = BitcoinNetwork.values.firstWhere(
      (network) => network.env == settings.environment.networkEnv,
    );
    if (settings.isSuperuser != true ||
        settings.isDevModeEnabled != true ||
        !NetworkCapabilities.supports(
          active,
          NetworkCapability.silentPayments,
        ) ||
        (network != null && network != active) ||
        (config != null && config.network != active)) {
      return const Ok(false);
    }
    final bool admitted;
    switch (await _configRepository.fetchOrNull()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        admitted =
            (value == null ? allowUnconfigured : value.network == active) &&
            (config == null || value == config);
    }
    if (!admitted) return const Ok(false);
    final current = (await _settingsRepository.fetch()).fold(
      (value) => value,
      (_) => null,
    );
    if (current == null) {
      return const Err(SilentUnexpected('Silent preferences read failed'));
    }
    return Ok(
      current.isSuperuser == true &&
          current.isDevModeEnabled == true &&
          current.environment == settings.environment,
    );
  }
}
