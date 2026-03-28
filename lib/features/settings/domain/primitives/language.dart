enum Language {
  unitedStatesEnglish('en', 'US', 'English'),
  franceFrench('fr', 'FR', 'Français'),
  spanish('es', 'ES', 'Español'),
  finnish('fi', 'FI', 'Suomi'),
  ukrainian('uk', 'UA', 'Українська'),
  russian('ru', 'RU', 'Русский'),
  german('de', 'DE', 'Deutsch'),
  italian('it', 'IT', 'Italiano'),
  portuguese('pt', 'PT', 'Português'),
  simplifiedChinese('zh', 'CN', '简体中文');

  final String languageCode;
  final String? countryCode;
  final String label;

  const Language(this.languageCode, this.countryCode, this.label);
}
