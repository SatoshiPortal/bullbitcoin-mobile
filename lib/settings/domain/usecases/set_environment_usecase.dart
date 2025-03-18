import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class SetEnvironmentUsecase {
  final SettingsRepository _settingsRepository;

  SetEnvironmentUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(Environment environment) async {
    await _settingsRepository.setEnvironment(environment);
  }
}
