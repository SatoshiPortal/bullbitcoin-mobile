import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SetErrorReportingUsecase {
  final SettingsRepository _settingsRepository;

  SetErrorReportingUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(bool enabled) async {
    await _settingsRepository.setErrorReportingEnabled(enabled);
  }
}
