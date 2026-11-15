import 'package:primitives/primitives.dart';

import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';
import '../repositories/vault_repository.dart';

final class ParseVaultUsecase {
  final VaultRepository _vaults;
  const ParseVaultUsecase(this._vaults);
  Result<EncryptedVault, RecoverBullFailure> execute(String content) =>
      _vaults.parse(content);
}
