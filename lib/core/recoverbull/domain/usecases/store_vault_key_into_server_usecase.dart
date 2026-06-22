import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Stores a backup key on the server with password protection
class StoreVaultKeyIntoServerUsecase {
  final RecoverBullRepository _recoverBullRepository;

  StoreVaultKeyIntoServerUsecase({required this._recoverBullRepository});

  Future<Result<Null, RecoverBullCoreFailure>> execute({
    required String password,
    required EncryptedVault vault,
    required String vaultKey,
  }) {
    return _recoverBullRepository.storeVaultKey(
      vault.id,
      password,
      vault.salt,
      vaultKey,
    );
  }
}
