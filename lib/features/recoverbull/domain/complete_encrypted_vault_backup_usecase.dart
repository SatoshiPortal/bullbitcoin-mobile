import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class CompleteEncryptedVaultBackupUsecase {
  final WalletRepository _wallets;

  const CompleteEncryptedVaultBackupUsecase(this._wallets);

  Future<Result<void, RecoverBullFailure>> execute({
    required String walletId,
  }) async {
    try {
      await _wallets.updateEncryptedBackupTime(
        time: DateTime.now(),
        walletId: walletId,
      );
      return const Ok(null);
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to record encrypted vault completion',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(VaultStatusPersistenceFailure());
    }
  }
}
