import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';
import '../repositories/vault_repository.dart';

final class DeriveVaultKeyUsecase {
  final VaultRepository _vaults;
  const DeriveVaultKeyUsecase(this._vaults);
  Future<Result<VaultKey, RecoverBullFailure>> execute(EncryptedVault vault) =>
      _vaults.deriveKey(vault);
}
