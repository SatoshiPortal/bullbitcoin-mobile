import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_store_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:bull_logger/bull_logger.dart';

class ApplyPendingWizardChoicesUsecase {
  final WizardRepository _wizardRepository;
  final SettingsRepository _settingsRepository;
  final WalletBackupFacade _walletBackup;

  ApplyPendingWizardChoicesUsecase({
    required this._wizardRepository,
    required this._settingsRepository,
    required this._walletBackup,
  });

  Future<Result<void, WizardFailure>> execute({
    bool backupReady = false,
  }) async {
    try {
      final choices = await _wizardRepository.readPending();
      if (choices == null) return const Ok(null);
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
      final backupChoice = choices.dataBackupEnabled;
      final hasBackupChoice =
          choices.touched.contains(WizardField.dataBackupEnabled) &&
          backupChoice != null;
      var backupFailed = false;
      if (hasBackupChoice && backupReady) {
        final result = await _walletBackup.setEnabled(
          backupChoice,
          onlyIfUndecided: true,
        );
        backupFailed = result is Err;
      }
      final keepBackupChoice =
          hasBackupChoice && (!backupReady || backupFailed);
      // Retry failed settings without overwriting later edits to successful ones.
      // Backup consent remains pending until a wallet can apply it.
      if (failed.isEmpty) {
        await _wizardRepository.clearPending(
          keepDataBackupChoice: keepBackupChoice,
        );
      } else {
        final saved = await _wizardRepository.savePending(
          WizardChoices(
            language: choices.language,
            themeMode: choices.themeMode,
            defaultCurrency: choices.defaultCurrency,
            reportingConsent: choices.reportingConsent,
            dataBackupEnabled: choices.dataBackupEnabled,
            touched: {
              ...failed,
              if (keepBackupChoice) WizardField.dataBackupEnabled,
            },
          ),
        );
        if (saved is Err) return const Err(WizardApplyFailure());
      }
      if (backupFailed) return const Err(WizardApplyFailure());
      return (await _wizardRepository.markComplete()).mapErr(
        (_) => const WizardApplyFailure(),
      );
    } on Exception {
      return const Err(WizardApplyFailure());
    }
  }
}
