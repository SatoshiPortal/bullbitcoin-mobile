import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:meta/meta.dart';

class CompleteEncryptedVaultBackupUsecase {
  final WalletRepository _walletRepository;

  CompleteEncryptedVaultBackupUsecase(this._walletRepository);

  @useResult
  Future<Result<void, RecoverBullFailure>> execute({
    required String walletId,
  }) async {
    try {
      await _walletRepository.updateEncryptedBackupTime(
        time: DateTime.now(),
        walletId: walletId,
      );
      return const Ok(null);
    } on WalletError catch (e, st) {
      return _failure(e, st);
    } on Exception catch (e, st) {
      return _failure(e, st);
    }
  }

  Err<void, RecoverBullFailure> _failure(Object error, StackTrace trace) {
    log.severe(
      message: 'completeEncryptedVaultBackup failed',
      error: error,
      trace: trace,
    );
    return Err(VaultStatusPersistenceFailure(error.toString()));
  }
}
