import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class WizardChoices {
  const WizardChoices({
    this.language = Language.unitedStatesEnglish,
    this.themeMode = AppThemeMode.system,
    this.errorReporting = true,
  });

  final Language language;
  final AppThemeMode themeMode;
  final bool errorReporting;

  WizardChoices copyWith({
    Language? language,
    AppThemeMode? themeMode,
    bool? errorReporting,
  }) {
    return WizardChoices(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      errorReporting: errorReporting ?? this.errorReporting,
    );
  }
}
