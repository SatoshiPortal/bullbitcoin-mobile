import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:meta/meta.dart';

/// The contents of the backup the server holds, or null when it holds none.
final class FetchRemoteWalletBackupContentsUsecase {
  final WalletBackupFacade _walletBackup;

  const FetchRemoteWalletBackupContentsUsecase(this._walletBackup);

  @useResult
  Future<Result<WalletBackupContents?, BackupSettingsFailure>>
  execute() async => switch (await _walletBackup.fetchRemoteContents()) {
    Ok(:final value) => Ok(value),
    Err(:final failure) => Err(mapWalletBackupFailure(failure)),
  };
}
