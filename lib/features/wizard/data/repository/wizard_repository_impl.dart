import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

/// Bump this integer whenever the wizard gains new mandatory questions.
/// Users whose stored version is lower will see the wizard again on
/// next launch — fresh installs and existing users alike, since the
/// wizard always runs pre-init.
///
/// WARNING: bumping this re-shows the wizard. The bloc stages choices
/// in prefs on completion; `ApplyPendingWizardChoicesUsecase` flushes
/// them to SQLite via `setLanguage` / `setThemeMode` / `setCurrency` /
/// `setErrorReportingEnabled` — but only for fields the user explicitly
/// touched (see [WizardChoices.touched]). A user who taps Skip without
/// changing anything therefore preserves their existing settings
/// unchanged.
const int kCurrentWizardVersion = 1;

class WizardRepositoryImpl implements WizardRepository {
  WizardRepositoryImpl(this._datasource);

  final WizardLocalDatasource _datasource;

  @override
  Future<bool> isComplete() async {
    final stored = await _datasource.readCompletedVersion() ?? 0;
    return stored >= kCurrentWizardVersion;
  }

  @override
  Future<void> markComplete() =>
      _datasource.writeCompletedVersion(kCurrentWizardVersion);

  @override
  Future<void> savePending(WizardChoices choices) async {
    await clearPending();
    if (choices.touched.isEmpty) return;
    await _datasource.writePendingVersion(kCurrentWizardVersion);
    if (choices.touched.contains(WizardField.language)) {
      await _datasource.writePendingLanguage(choices.language.name);
    }
    if (choices.touched.contains(WizardField.themeMode)) {
      await _datasource.writePendingThemeMode(choices.themeMode.name);
    }
    if (choices.touched.contains(WizardField.defaultCurrency)) {
      await _datasource.writePendingCurrency(choices.defaultCurrency);
    }
    final consent = choices.reportingConsent;
    if (choices.touched.contains(WizardField.reportingConsent) &&
        consent != null) {
      await _datasource.writePendingErrorReporting(consent);
    }
  }

  /// Returns `null` when nothing is staged OR when the staged blob was
  /// written by a different `kCurrentWizardVersion` (also wiped as a
  /// side effect — those values belong to a previous wizard schema and
  /// must not leak into the new one).
  @override
  Future<WizardChoices?> readPending() async {
    final languageName = await _datasource.readPendingLanguage();
    final themeName = await _datasource.readPendingThemeMode();
    final currency = await _datasource.readPendingCurrency();
    final errorReporting = await _datasource.readPendingErrorReporting();
    if (languageName == null &&
        themeName == null &&
        currency == null &&
        errorReporting == null) {
      return null;
    }
    final pendingVersion = await _datasource.readPendingVersion() ?? 0;
    if (pendingVersion != kCurrentWizardVersion) {
      await clearPending();
      return null;
    }
    final touched = <WizardField>{};
    if (languageName != null) touched.add(WizardField.language);
    if (themeName != null) touched.add(WizardField.themeMode);
    if (currency != null) touched.add(WizardField.defaultCurrency);
    if (errorReporting != null) touched.add(WizardField.reportingConsent);
    return WizardChoices(
      language: languageName == null
          ? Language.unitedStatesEnglish
          : Language.fromName(languageName),
      themeMode: themeName == null
          ? AppThemeMode.system
          : AppThemeMode.fromName(themeName),
      defaultCurrency: currency ?? 'USD',
      reportingConsent: errorReporting,
      touched: touched,
    );
  }

  @override
  Future<void> clearPending() => _datasource.clearAllPending();
}
