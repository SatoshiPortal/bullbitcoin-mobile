import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class WizardChoices {
  const WizardChoices({
    this.language = Language.unitedStatesEnglish,
    this.themeMode = AppThemeMode.system,
    this.reportingConsent = true,
  });

  final Language language;
  final AppThemeMode themeMode;
  final bool reportingConsent;

  WizardChoices copyWith({
    Language? language,
    AppThemeMode? themeMode,
    bool? reportingConsent,
  }) {
    return WizardChoices(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      reportingConsent: reportingConsent ?? this.reportingConsent,
    );
  }
}
