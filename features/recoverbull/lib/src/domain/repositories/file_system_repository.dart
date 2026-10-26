import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';

abstract interface class FileSystemRepository {
  @useResult
  Future<Result<Null, RecoverBullFailure>> saveVault(EncryptedVault vault);

  @useResult
  Future<Result<EncryptedVault, RecoverBullFailure>> pickVault();

  @useResult
  Future<Result<Null, RecoverBullFailure>> saveFile(
    String content,
    String filename,
  );
}
