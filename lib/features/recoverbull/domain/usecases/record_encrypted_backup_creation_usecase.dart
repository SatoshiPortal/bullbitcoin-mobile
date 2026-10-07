import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';

class RecordEncryptedBackupCreationUsecase {
  final WalletRepository _walletRepository;

  RecordEncryptedBackupCreationUsecase(this._walletRepository);

  Future<Result<Null, RecoverBullFailure>> execute({
    required String walletId,
  }) async {
    try {
      await _walletRepository.recordEncryptedBackupCreation(
        time: DateTime.now(),
        walletId: walletId,
      );
      return const Ok(null);
    } catch (_, stackTrace) {
      log.severe(
        message: 'Could not record encrypted backup creation',
        error: 'Backup metadata storage failed',
        trace: stackTrace,
      );
      return const Err(VaultCreationFailure());
    }
  }
}
