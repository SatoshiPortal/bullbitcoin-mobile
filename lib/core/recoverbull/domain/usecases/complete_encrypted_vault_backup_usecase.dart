import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bull_logger/bull_logger.dart';

class CompleteEncryptedVaultBackupUsecase {
  final WalletRepository _walletRepository;

  CompleteEncryptedVaultBackupUsecase({required this._walletRepository});

  Future<Result<Null, RecoverBullCoreFailure>> execute({
    required String walletId,
  }) async {
    try {
      await _walletRepository.updateEncryptedBackupTime(
        time: DateTime.now(),
        walletId: walletId,
      );
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'completeEncryptedVaultBackup failed',
        error: e,
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedCoreFailure('Backup status update failed'),
      );
    }
  }
}
