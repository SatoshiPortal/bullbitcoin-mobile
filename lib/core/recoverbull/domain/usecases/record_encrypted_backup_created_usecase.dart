import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_backup_metadata_port.dart';
import 'package:bull_logger/bull_logger.dart';

class RecordEncryptedBackupCreatedUsecase {
  final WalletBackupMetadataPort _walletBackupMetadataPort;

  const RecordEncryptedBackupCreatedUsecase(this._walletBackupMetadataPort);

  Future<Result<Null, RecoverBullCoreFailure>> execute({
    required String walletId,
  }) async {
    try {
      await _walletBackupMetadataPort.recordEncryptedBackupCreated(
        walletId: walletId,
        time: DateTime.now(),
      );
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'recordEncryptedBackupCreated failed',
        error: e,
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedCoreFailure('Could not record backup creation'),
      );
    }
  }
}
