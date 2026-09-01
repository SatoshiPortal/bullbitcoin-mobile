import './datasources/file_storage_datasource.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// Data boundary for local file pick/save. Catches picker/IO exceptions and
/// validates the picked file, returning a [RecoverBullFailure].
class FileSystemRepository {
  final LogSink log;
  final FileStorageDatasource _fileStorageDataSource;

  FileSystemRepository({
    required this.log,
    required FileStorageDatasource datasource,
  }) : _fileStorageDataSource = datasource;

  /// Picks a file and validates it is an encrypted vault. (Validation lives
  /// here, not in the use-case.)
  Future<Result<EncryptedVault, RecoverBullFailure>> pickVault() async {
    try {
      final file = await _fileStorageDataSource.pickFile();
      final fileContent = await file.readAsString();
      if (!EncryptedVault.isValid(fileContent)) {
        return const Err(InvalidVaultFileFailure());
      }
      return Ok(EncryptedVault(file: fileContent));
    } catch (e, st) {
      log.error('pickVault failed', error: e, trace: st);
      return const Err(RecoverBullUnexpectedFailure('File operation failed'));
    }
  }

  Future<Result<Null, RecoverBullFailure>> saveFile(
    String content,
    String filename,
  ) async {
    try {
      await _fileStorageDataSource.saveFile(content, filename);
      return const Ok(null);
    } catch (e, st) {
      log.error('saveFile failed', error: e, trace: st);
      return const Err(RecoverBullUnexpectedFailure('File operation failed'));
    }
  }
}
