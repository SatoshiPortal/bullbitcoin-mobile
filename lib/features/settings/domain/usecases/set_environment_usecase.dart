import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class SetEnvironmentUsecase {
  final SettingsRepository _settingsRepository;

  SetEnvironmentUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(Environment environment) async {
    await _settingsRepository.setEnvironment(environment);
  }
}
