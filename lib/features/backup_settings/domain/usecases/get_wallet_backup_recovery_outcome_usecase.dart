import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:primitives/primitives.dart';

final class GetWalletBackupRecoveryOutcomeUsecase {
  final WalletBackupFacade _walletBackup;

  const GetWalletBackupRecoveryOutcomeUsecase(this._walletBackup);

  Future<Result<WalletBackupRecoveryOutcome?, BackupSettingsFailure>>
  execute() async => (await _walletBackup.getLastRecoveryOutcome()).mapErr(
    mapWalletBackupFailure,
  );
}
