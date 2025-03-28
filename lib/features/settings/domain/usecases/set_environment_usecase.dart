
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class SetEnvironmentUsecase {
  final SettingsRepository _settingsRepository;

  SetEnvironmentUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(Environment environment) async {
    await _settingsRepository.setEnvironment(environment);
  }
}
