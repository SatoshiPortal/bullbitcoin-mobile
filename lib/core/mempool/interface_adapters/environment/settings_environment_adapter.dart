import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class SettingsEnvironmentAdapter implements MempoolEnvironmentPort {
  final SettingsRepository _settingsRepository;

  SettingsEnvironmentAdapter({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  @override
  Future<Environment> getEnvironment() async {
    final settings = await _settingsRepository.fetch();
    return settings.environment;
  }
}
