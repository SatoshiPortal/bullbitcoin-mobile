import 'package:bb_mobile/features/language/domain/entities/language.dart';
import 'package:bb_mobile/features/language/domain/repositories/language_settings_repository.dart';

class GetLanguageUsecase {
  final LanguageSettingsRepository _languageSettingsRepository;

  GetLanguageUsecase({
    required LanguageSettingsRepository languageSettingsRepository,
  }) : _languageSettingsRepository = languageSettingsRepository;

  Future<Language?> execute() async {
    final language = await _languageSettingsRepository.getLanguage();
    return language;
  }
}
