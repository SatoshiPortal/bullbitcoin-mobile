import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/wizard_choices.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bump this integer whenever the wizard gains new mandatory questions.
/// Users whose stored version is lower will see the wizard again after
/// upgrading.
const int kCurrentWizardVersion = 1;

/// Gates whether the install/upgrade wizard must be shown before the rest
/// of the app initializes, and stages the user's answers until the SQLite
/// settings repository becomes available.
///
/// Intentionally depends only on [SharedPreferences] so it cannot fail
/// because of the heavier initialization that happens in `Bull.init`.
class WizardGate {
  static const String _versionKey = 'wizard_completed_version';
  static const String _pendingLanguageKey = 'wizard_pending_language';
  static const String _pendingThemeKey = 'wizard_pending_theme_mode';
  static const String _pendingErrorReportingKey =
      'wizard_pending_error_reporting';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_versionKey) ?? 0;
    return stored < kCurrentWizardVersion;
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_versionKey, kCurrentWizardVersion);
  }

  static Future<void> savePending(WizardChoices choices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingLanguageKey, choices.language.name);
    await prefs.setString(_pendingThemeKey, choices.themeMode.name);
    await prefs.setBool(_pendingErrorReportingKey, choices.errorReporting);
  }

  static Future<WizardChoices?> readPending() async {
    final prefs = await SharedPreferences.getInstance();
    final languageName = prefs.getString(_pendingLanguageKey);
    final themeName = prefs.getString(_pendingThemeKey);
    final errorReporting = prefs.getBool(_pendingErrorReportingKey);
    if (languageName == null && themeName == null && errorReporting == null) {
      return null;
    }

    return WizardChoices(
      language: languageName == null
          ? Language.unitedStatesEnglish
          : Language.fromName(languageName),
      themeMode: themeName == null
          ? AppThemeMode.system
          : AppThemeMode.fromName(themeName),
      errorReporting: errorReporting ?? true,
    );
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingLanguageKey);
    await prefs.remove(_pendingThemeKey);
    await prefs.remove(_pendingErrorReportingKey);
  }
}
