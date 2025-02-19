import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';

class GetEnvironmentUseCase {
  final SettingsRepository _settingsRepository;

  GetEnvironmentUseCase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<Environment> execute() async {
    final environment = await _settingsRepository.getEnvironment();
    return environment;
  }
}
