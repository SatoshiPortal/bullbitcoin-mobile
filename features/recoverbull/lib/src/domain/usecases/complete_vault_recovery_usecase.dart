import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../entities/decrypted_vault.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_lifecycle_port.dart';
import 'restore_vault_usecase.dart';

final class CompleteVaultRecoveryUsecase {
  final LogSink log;
  final RestoreVaultUsecase restore;
  final RecoverBullLifecyclePort? lifecycle;
  final Future<void> Function()? onWalletUpdated;

  const CompleteVaultRecoveryUsecase({
    required this.log,
    required this.restore,
    this.lifecycle,
    this.onWalletUpdated,
  });

  Future<Result<Null, RecoverBullFailure>> execute({
    required DecryptedVault vault,
    required bool Function() cancelled,
  }) async {
    final restored = await restore.execute(decryptedVault: vault);
    if (cancelled()) return const Err(VaultRecoveryFailure());
    switch (restored) {
      case Err():
        return const Err(VaultRecoveryFailure());
      case Ok(:final value):
        try {
          await lifecycle?.markVerified(value);
        } on Exception {
          log.warning('recoverbull.lifecycle.mark_verified_failed');
        }
        if (cancelled()) return const Err(VaultRecoveryFailure());
        try {
          await onWalletUpdated?.call();
        } on Exception {
          log.warning('recoverbull.wallet_refresh.restore_failed');
        }
        return const Ok(null);
    }
  }
}
