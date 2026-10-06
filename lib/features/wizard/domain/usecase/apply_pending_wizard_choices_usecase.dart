import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_store_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

/// Flushes the pre-init wizard's pending choices (collected in
/// [SharedPreferences] before the locator was up) to the SQLite
/// settings repository, then marks the wizard complete and clears the
/// pending blob. Only commits fields the user actively touched. Safe
/// to call when nothing is staged — short-circuits.
class ApplyPendingWizardChoicesUsecase {
  ApplyPendingWizardChoicesUsecase({
    required this._wizardRepository,
    required this._settingsRepository,
  });

  final WizardRepository _wizardRepository;
  final SettingsRepository _settingsRepository;

  Future<void> execute() async {
    final choices = await _wizardRepository.readPending();
    if (choices == null) return;
    // The repository logged the raw reason at its boundary; what matters here
    // is which choices did not land.
    final failed = <WizardField>{};
    void note(Result<void, SettingsStoreFailure> result, WizardField field) {
      if (result case Err(:final failure)) {
        failed.add(field);
        log.warning(
          'Wizard choice "${field.name}" could not be applied: '
          '${failure.runtimeType}',
        );
      }
    }

    if (choices.touched.contains(WizardField.language)) {
      note(
        await _settingsRepository.setLanguage(choices.language),
        WizardField.language,
      );
    }
    if (choices.touched.contains(WizardField.themeMode)) {
      note(
        await _settingsRepository.setThemeMode(choices.themeMode),
        WizardField.themeMode,
      );
    }
    if (choices.touched.contains(WizardField.defaultCurrency)) {
      note(
        await _settingsRepository.setCurrency(choices.defaultCurrency),
        WizardField.defaultCurrency,
      );
    }
    final consent = choices.reportingConsent;
    if (choices.touched.contains(WizardField.reportingConsent) &&
        consent != null) {
      note(
        await _settingsRepository.setErrorReportingEnabled(consent),
        WizardField.reportingConsent,
      );
    }

    // Keep only the choices that failed pending, so the next launch retries
    // just those. Clearing everything would drop what the user picked during
    // onboarding on a transient storage error; keeping everything would
    // re-apply choices that already landed, and so silently reset any of them
    // the user has since changed in Settings. savePending rewrites the staged
    // set from scratch, writing only the fields in `touched`.
    //
    // Known edge: if the user changes a field whose write failed before the
    // next launch, the retry still overwrites it with the onboarding value.
    //
    // The wizard is still marked complete: making someone redo onboarding is
    // worse than retrying the writes quietly, and this runs before there is
    // any UI to report to.
    if (failed.isEmpty) {
      await _wizardRepository.clearPending();
    } else {
      await _wizardRepository.savePending(
        WizardChoices(
          language: choices.language,
          themeMode: choices.themeMode,
          defaultCurrency: choices.defaultCurrency,
          reportingConsent: choices.reportingConsent,
          touched: failed,
        ),
      );
    }
    await _wizardRepository.markComplete();
  }
}
