import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class WatchDevModeChangesUsecase {
  final SettingsRepository _settingsRepository;

  WatchDevModeChangesUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Stream<bool> execute() {
    return _settingsRepository.devModeChangeStream;
  }
}
