import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

class DecryptVaultUsecase {
  final RecoverBullRepository _recoverBull;

  DecryptVaultUsecase({required RecoverBullRepository recoverBullRepository})
    : _recoverBull = recoverBullRepository;

  Result<DecryptedVault, RecoverBullCoreFailure> execute({
    required EncryptedVault vault,
    required String vaultKey,
  }) {
    return _recoverBull.restoreVault(vault: vault, vaultKey: vaultKey);
  }
}
