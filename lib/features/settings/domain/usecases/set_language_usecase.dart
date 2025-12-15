import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';

class SetLanguageUsecase {
  final SettingsRepository _settingsRepository;

  SetLanguageUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(Language language) async {
    await _settingsRepository.setLanguage(language);
  }
}
