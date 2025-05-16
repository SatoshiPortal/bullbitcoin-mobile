import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class GetSettingsUsecase {
  final SettingsRepository _settingsRepository;

  GetSettingsUsecase({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  Future<SettingsEntity> execute() async => await _settingsRepository.fetch();
}
