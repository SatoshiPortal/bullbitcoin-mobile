import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';

/// Admits SP only for the active network and the exact captured configuration.
/// Missing configuration permits setup, never a live snapshot on its own.
class GetSpFeatureGateUsecase {
  final SettingsRepository _settingsRepository;
  final SpBackendConfigRepository _configRepository;

  GetSpFeatureGateUsecase({
    required this._settingsRepository,
    required this._configRepository,
  });

  Future<bool> execute({
    BitcoinNetwork? network,
    SpBackendConfig? config,
    bool allowUnconfigured = false,
  }) async {
    final settings = await _settingsRepository.fetch();
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
      return false;
    }
    final admitted = switch (await _configRepository.fetchOrNull()) {
      Err() => false,
      Ok(:final value) =>
        (value == null ? allowUnconfigured : value.network == active) &&
            (config == null || value == config),
    };
    if (!admitted) return false;
    final current = await _settingsRepository.fetch();
    return current.isSuperuser == true &&
        current.isDevModeEnabled == true &&
        current.environment == settings.environment;
  }
}
