import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:secrets/secrets.dart';

/// Compares a candidate inside the secrets package without exposing the stored value.
class VerifyBackupPassphraseUsecase {
  const VerifyBackupPassphraseUsecase();

  @useResult
  Future<Result<bool, TestWalletBackupFailure>> execute(
    Secret secret,
    String candidate,
  ) async => switch (await secret.verify.passphrase(candidate)) {
    Ok(:final value) => Ok(value),
    Err() => const Err(TestWalletBackupSeedUnavailableFailure()),
  };
}
