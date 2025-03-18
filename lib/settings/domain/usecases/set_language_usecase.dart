import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class SetLanguageUsecase {
  final SettingsRepository _settingsRepository;

  SetLanguageUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(Language language) async {
    await _settingsRepository.setLanguage(language);
  }
}
