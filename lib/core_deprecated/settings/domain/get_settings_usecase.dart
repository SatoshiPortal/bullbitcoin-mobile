import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';

class GetSettingsUsecase {
  final SettingsRepository _settingsRepository;

  GetSettingsUsecase({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  Future<SettingsEntity> execute() async => await _settingsRepository.fetch();
}
