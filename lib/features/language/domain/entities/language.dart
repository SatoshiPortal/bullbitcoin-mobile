import 'package:flutter/widgets.dart';

enum Language {
  unitedStatesEnglish('en', 'US'),
  canadianFrench('fr', 'CA'),
  franceFrench('fr', 'FR');

  final String languageCode;
  final String? countryCode;

  const Language(this.languageCode, this.countryCode);

  static Language? fromName(String name) {
    try {
      return Language.values.firstWhere((language) => language.name == name);
    } catch (e) {
      return null;
    }
  }
}

extension LanguageExtension on Language {
  Locale get locale => Locale(languageCode, countryCode);
  bool isLocale(Locale locale) =>
      locale.languageCode == languageCode && locale.countryCode == countryCode;
}
