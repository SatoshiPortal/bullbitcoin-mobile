import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:meta/meta.dart';

final class SetWalletBackupServerUsecase {
  final WalletBackupFacade _walletBackup;

  const SetWalletBackupServerUsecase(this._walletBackup);

  @useResult
  Future<Result<void, BackupSettingsFailure>> execute(String value) async =>
      switch (await _walletBackup.setServer(value)) {
        Ok() => const Ok(null),
        Err(:final failure) => Err(mapWalletBackupFailure(failure)),
      };
}
