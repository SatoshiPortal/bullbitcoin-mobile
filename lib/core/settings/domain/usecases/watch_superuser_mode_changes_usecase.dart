import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class WatchSuperuserModeChangesUsecase {
  final SettingsRepository _settingsRepository;

  WatchSuperuserModeChangesUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Stream<bool> execute() {
    return _settingsRepository.superuserModeChangeStream;
  }
}
