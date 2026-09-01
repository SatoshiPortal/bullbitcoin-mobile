import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:primitives/primitives.dart';

final class SetWalletBackupEnabledUsecase {
  final WalletBackupFacade _walletBackup;

  const SetWalletBackupEnabledUsecase(this._walletBackup);

  Future<Result<void, BackupSettingsFailure>> execute(bool enabled) async =>
      (await _walletBackup.setEnabled(enabled)).mapErr(mapWalletBackupFailure);
}
