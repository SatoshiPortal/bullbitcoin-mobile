import '../repositories/recoverbull_repository.dart';
import '../entities/decrypted_vault.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

class DecryptVaultUsecase {
  final RecoverBullRepository _recoverBull;

  DecryptVaultUsecase({required RecoverBullRepository recoverBullRepository})
    : _recoverBull = recoverBullRepository;

  Result<DecryptedVault, RecoverBullFailure> execute({
    required EncryptedVault vault,
    required String vaultKey,
  }) {
    final result = _recoverBull.restoreVault(vault: vault, vaultKey: vaultKey);
    return result;
  }
}
