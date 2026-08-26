import 'package:bull_recoverbull/src/data/datasources/file_storage_datasource.dart';
import 'package:bull_recoverbull/src/domain/entity/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/support/logger.dart';
import 'package:primitives/primitives.dart';

/// Data boundary for local file pick/save. Catches picker/IO exceptions and
/// validates the picked file, returning a [RecoverBullCoreFailure].
class FileSystemRepository {
  final FileStorageDatasource _fileStorageDataSource;

  FileSystemRepository({required FileStorageDatasource datasource})
    : _fileStorageDataSource = datasource;

  /// Picks a file and validates it is an encrypted vault. (Validation lives
  /// here, not in the use-case.)
  Future<Result<EncryptedVault, RecoverBullCoreFailure>> pickVault() async {
    try {
      final file = await _fileStorageDataSource.pickFile();
      final fileContent = await file.readAsString();
      if (!EncryptedVault.isValid(fileContent)) {
        return const Err(InvalidVaultFileFailure());
      }
      return Ok(EncryptedVault(file: fileContent));
    } catch (e, st) {
      log.severe(message: 'pickVault failed', error: e, trace: st);
      return const Err(
        RecoverBullUnexpectedCoreFailure('File operation failed'),
      );
    }
  }

  Future<Result<Null, RecoverBullCoreFailure>> saveFile(
    String content,
    String filename,
  ) async {
    try {
      await _fileStorageDataSource.saveFile(content, filename);
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'saveFile failed', error: e, trace: st);
      return const Err(
        RecoverBullUnexpectedCoreFailure('File operation failed'),
      );
    }
  }
}
