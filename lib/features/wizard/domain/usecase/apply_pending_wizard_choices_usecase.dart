import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:primitives/primitives.dart';

/// Flushes the pre-init wizard's pending choices (collected in
/// [SharedPreferences] before the locator was up) to the SQLite
/// settings repository, then marks the wizard complete and clears the
/// pending blob. Only commits fields the user actively touched. Safe
/// to call when nothing is staged — short-circuits.
class ApplyPendingWizardChoicesUsecase {
  ApplyPendingWizardChoicesUsecase({
    required this._wizardRepository,
    required this._settingsRepository,
    required this._walletBackup,
  });

  final WizardRepository _wizardRepository;
  final SettingsRepository _settingsRepository;
  final WalletBackupFacade _walletBackup;

  Future<Result<void, WizardFailure>> execute() async {
    try {
      final choices = await _wizardRepository.readPending();
      if (choices == null) return const Ok(null);
      final backupEnabled = choices.metadataBackupEnabled;
      if (choices.touched.contains(WizardField.metadataBackupEnabled) &&
          backupEnabled != null) {
        if (await _walletBackup.setEnabled(backupEnabled) case Err()) {
          return const Err(WizardApplyFailure());
        }
      }
      if (choices.touched.contains(WizardField.language)) {
        await _settingsRepository.setLanguage(choices.language);
      }
      if (choices.touched.contains(WizardField.themeMode)) {
        await _settingsRepository.setThemeMode(choices.themeMode);
      }
      if (choices.touched.contains(WizardField.defaultCurrency)) {
        await _settingsRepository.setCurrency(choices.defaultCurrency);
      }
      final consent = choices.reportingConsent;
      if (choices.touched.contains(WizardField.reportingConsent) &&
          consent != null) {
        await _settingsRepository.setErrorReportingEnabled(consent);
      }
      await _wizardRepository.clearPending();
      await _wizardRepository.markComplete();
      return const Ok(null);
    } on Exception {
      return const Err(WizardApplyFailure());
    }
  }
}
