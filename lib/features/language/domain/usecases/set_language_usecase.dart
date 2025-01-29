import 'package:bb_mobile/features/language/domain/entities/language.dart';
import 'package:bb_mobile/features/language/domain/repositories/language_settings_repository.dart';

class SetLanguageUseCase {
  final LanguageSettingsRepository _languageSettingsRepository;

  SetLanguageUseCase({
    required LanguageSettingsRepository languageSettingsRepository,
  }) : _languageSettingsRepository = languageSettingsRepository;

  Future<void> execute(Language language) async {
    await _languageSettingsRepository.setLanguage(language);
  }
}
