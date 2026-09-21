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
    // is whether every choice actually landed.
    var allApplied = true;
    void note(Result<void, SettingsStoreFailure> result, String field) {
      if (result case Err(:final failure)) {
        allApplied = false;
        log.warning(
          'Wizard choice "$field" could not be applied: '
          '${failure.runtimeType}',
        );
      }
    }

    if (choices.touched.contains(WizardField.language)) {
      note(await _settingsRepository.setLanguage(choices.language), 'language');
    }
    if (choices.touched.contains(WizardField.themeMode)) {
      note(
        await _settingsRepository.setThemeMode(choices.themeMode),
        'themeMode',
      );
    }
    if (choices.touched.contains(WizardField.defaultCurrency)) {
      note(
        await _settingsRepository.setCurrency(choices.defaultCurrency),
        'defaultCurrency',
      );
    }
    final consent = choices.reportingConsent;
    if (choices.touched.contains(WizardField.reportingConsent) &&
        consent != null) {
      note(
        await _settingsRepository.setErrorReportingEnabled(consent),
        'reportingConsent',
      );
    }

    // Keep the pending choices when a write failed so the next launch retries
    // them. Clearing regardless would drop what the user picked during
    // onboarding on a transient storage error, with no way to get it back.
    //
    // The wizard is still marked complete: making someone redo onboarding is
    // worse than retrying the writes quietly, and this runs before there is
    // any UI to report to.
    if (allApplied) {
      await _wizardRepository.clearPending();
    }
    await _wizardRepository.markComplete();
  }
}
