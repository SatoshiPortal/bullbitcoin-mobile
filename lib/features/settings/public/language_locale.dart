import 'dart:ui' show Locale;

import '../domain/settings_entity.dart' show Language;

extension LanguageExtension on Language {
  Locale get locale => Locale.fromSubtags(
    languageCode: languageCode,
    scriptCode: scriptCode,
    countryCode: countryCode,
  );
}
