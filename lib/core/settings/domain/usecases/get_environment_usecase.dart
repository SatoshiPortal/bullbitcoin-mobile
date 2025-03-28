
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

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
