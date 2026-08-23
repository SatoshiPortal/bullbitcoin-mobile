import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class UpdateTorSettingsUsecase {
  final SettingsRepository _settingsRepository;

  UpdateTorSettingsUsecase({required this._settingsRepository});

  Future<void> execute({
    required bool useTorProxy,
    required int torProxyPort,
  }) async {
    await _settingsRepository.setTorProxy(
      enabled: useTorProxy,
      port: torProxyPort,
    );
  }
}
