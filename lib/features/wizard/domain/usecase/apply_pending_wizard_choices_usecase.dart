import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';

/// Flushes the pre-init wizard's pending choices (collected in
/// [SharedPreferences] before the locator was up) to the SQLite
/// settings repository and wallet-metadata facade, then marks the wizard
/// complete and clears the pending blob. Only commits fields the user actively touched. Safe
/// to call when nothing is staged — short-circuits.
class ApplyPendingWizardChoicesUsecase {
  ApplyPendingWizardChoicesUsecase({
    required this._wizardRepository,
    required this._settingsRepository,
    required this._metadataBackup,
  });

  final WizardRepository _wizardRepository;
  final SettingsRepository _settingsRepository;
  final WalletMetadataBackupFacade _metadataBackup;

  Future<void> execute() async {
    final choices = await _wizardRepository.readPending();
    if (choices == null) return;
    if (choices.touched.contains(WizardField.language)) {
      await _settingsRepository.setLanguage(choices.language);
    }
    if (choices.touched.contains(WizardField.themeMode)) {
      await _settingsRepository.setThemeMode(choices.themeMode);
    }
    if (choices.touched.contains(WizardField.defaultCurrency)) {
      await _settingsRepository.setCurrency(choices.defaultCurrency);
    }
    final metadataBackupEnabled = choices.metadataBackupEnabled;
    if (choices.touched.contains(WizardField.metadataBackupEnabled) &&
        metadataBackupEnabled != null) {
      _requireMetadataUpdate(
        await _metadataBackup.setEnabled(metadataBackupEnabled),
      );
    }
    final consent = choices.reportingConsent;
    if (choices.touched.contains(WizardField.reportingConsent) &&
        consent != null) {
      await _settingsRepository.setErrorReportingEnabled(consent);
    }
    await _wizardRepository.clearPending();
    await _wizardRepository.markComplete();
  }

  void _requireMetadataUpdate(
    Result<WalletMetadataBackupState, WalletMetadataBackupFailure> result,
  ) {
    if (result case Err(:final failure)) {
      throw _ApplyPendingWizardChoicesException(
        'Could not apply wizard metadata backup choice: '
        '${failure.runtimeType}',
      );
    }
  }
}

final class _ApplyPendingWizardChoicesException implements Exception {
  final String message;

  const _ApplyPendingWizardChoicesException(this.message);

  @override
  String toString() => message;
}
