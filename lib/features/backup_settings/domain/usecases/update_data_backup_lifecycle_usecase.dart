import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

/// Consent/readiness gate for the existing app scope, not a publication owner.
class UpdateDataBackupLifecycleUsecase {
  final WalletBackupFacade _backups;
  final WizardFacade _wizard;
  int _request = 0;
  UpdateDataBackupLifecycleUsecase(this._backups, this._wizard);

  Stream<void> get changes => _backups.watchState();

  Future<Result<WalletBackupControl?, BackupSettingsFailure>> execute({
    required bool ready,
    required bool foreground,
  }) async {
    final request = ++_request;
    if (!ready || !foreground) {
      await _backups.stopAutomatic();
      return const Ok(null);
    }
    final pendingChoice = await _wizard.applyPendingBackupChoice();
    if (request != _request) return const Ok(null);
    if (pendingChoice case Err()) {
      await _backups.stopAutomatic();
      return const Err(BackupSettingsUnexpectedFailure());
    }
    final result = await _backups.getControl();
    if (request != _request) return const Ok(null);
    switch (result) {
      case Ok(value: final control) when control.enabled == true:
        _backups.resumeAutomatic();
      case Ok() || Err():
        // Missing/unreadable consent is closed; the settings screen reports
        // read failures through its existing control read.
        await _backups.stopAutomatic();
    }
    return result.mapErr(BackupSettingsFailure.fromDataBackup);
  }
}
