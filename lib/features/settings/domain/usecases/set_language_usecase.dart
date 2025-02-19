import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';

class SetLanguageUseCase {
  final SettingsRepository _settingsRepository;

  SetLanguageUseCase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(Language language) async {
    await _settingsRepository.setLanguage(language);
  }
}
