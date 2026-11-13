import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';

abstract interface class VaultFileRepository {
  @useResult
  Future<Result<EncryptedVault, RecoverBullFailure>> pick();
  @useResult
  Future<Result<void, RecoverBullFailure>> save(EncryptedVault vault);
  @useResult
  Future<Result<void, RecoverBullFailure>> export(
    String content,
    String filename,
  );
}
