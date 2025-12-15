import 'package:bb_mobile/core_deprecated/settings/domain/repositories/settings_repository.dart';

class UpdateTorSettingsUsecase {
  final SettingsRepository _settingsRepository;

  UpdateTorSettingsUsecase({required SettingsRepository settingsRepository})
      : _settingsRepository = settingsRepository;

  Future<void> execute({
    required bool useTorProxy,
    required int torProxyPort,
  }) async {
    await _settingsRepository.setUseTorProxy(useTorProxy);
    await _settingsRepository.setTorProxyPort(torProxyPort);
  }
}
