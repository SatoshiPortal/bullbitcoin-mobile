import 'package:bb_mobile/features/language/domain/entities/language.dart';

abstract class LanguageSettingsRepository {
  Future<void> setLanguage(Language language);
  Future<Language?> getLanguage();
}
