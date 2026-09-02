import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:primitives/primitives.dart';

typedef WalletRecoveryStatus = ({
  DateTime? lastPhysicalBackup,
  DateTime? lastEncryptedBackup,
});
typedef WalletBackupTestStatus = ({
  DateTime? latestPhysicalBackup,
  DateTime? latestEncryptedBackup,
});
typedef LoadWalletRecoveryEnvironment = Future<Environment> Function();
typedef LoadDefaultBitcoinWalletBackupStatuses =
    Future<List<WalletBackupTestStatus>> Function(Environment environment);

final class GetWalletRecoveryStatusUsecase {
  final LoadWalletRecoveryEnvironment _loadEnvironment;
  final LoadDefaultBitcoinWalletBackupStatuses _loadStatuses;

  const GetWalletRecoveryStatusUsecase(
    this._loadEnvironment,
    this._loadStatuses,
  );

  Future<Result<WalletRecoveryStatus, BackupSettingsFailure>> execute() async {
    try {
      final status = (await _loadStatuses(await _loadEnvironment())).single;
      return Ok((
        lastPhysicalBackup: status.latestPhysicalBackup,
        lastEncryptedBackup: status.latestEncryptedBackup,
      ));
    } on Exception catch (error, trace) {
      log.warning(
        'Could not load wallet recovery status',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(BackupSettingsUnexpectedFailure());
    }
  }
}
