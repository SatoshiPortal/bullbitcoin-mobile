import 'package:primitives/primitives.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';
import '../repositories/vault_file_repository.dart';

final class PickVaultUsecase {
  final VaultFileRepository _files;
  const PickVaultUsecase(this._files);
  Future<Result<EncryptedVault, RecoverBullFailure>> execute() => _files.pick();
}
