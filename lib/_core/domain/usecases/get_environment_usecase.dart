import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class GetEnvironmentUsecase {
  final SettingsRepository _settingsRepository;

  GetEnvironmentUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<Environment> execute() async {
    final environment = await _settingsRepository.getEnvironment();
    return environment;
  }
}
