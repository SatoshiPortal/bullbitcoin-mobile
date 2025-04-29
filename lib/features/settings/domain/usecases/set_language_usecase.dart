import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class SetLanguageUsecase {
  final SettingsRepository _settingsRepository;

  SetLanguageUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(Language language) async {
    await _settingsRepository.setLanguage(language);
  }
}
