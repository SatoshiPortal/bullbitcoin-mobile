import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

/// Consent/readiness gate for the existing app scope, not a publication owner.
class UpdateDataBackupLifecycleUsecase {
  final WalletBackupFacade _backups;
  int _request = 0;
  UpdateDataBackupLifecycleUsecase(this._backups);

  Stream<void> get changes => _backups.watchState();

  Future<void> execute({required bool ready, required bool foreground}) async {
    final request = ++_request;
    if (!ready || !foreground) {
      await _backups.stopAutomatic();
      return;
    }
    final result = await _backups.getControl();
    if (request != _request) return;
    switch (result) {
      case Ok(value: final control) when control.enabled == true:
        _backups.resumeAutomatic();
      case Ok() || Err():
        // Missing/unreadable consent is closed; the settings screen reports
        // read failures through its existing control read.
        await _backups.stopAutomatic();
    }
  }
}
