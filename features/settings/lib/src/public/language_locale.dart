import 'dart:ui' show Locale;

import 'package:preferences/preferences.dart' show Language;

extension LanguageExtension on Language {
  Locale get locale => Locale.fromSubtags(
    languageCode: languageCode,
    scriptCode: scriptCode,
    countryCode: countryCode,
  );
}
