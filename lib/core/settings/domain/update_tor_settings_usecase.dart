import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

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
