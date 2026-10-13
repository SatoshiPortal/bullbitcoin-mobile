import 'mappers/encrypted_vault_mapper.dart';
import '../domain/repositories/file_system_repository.dart';
export '../domain/repositories/file_system_repository.dart';
import './datasources/file_storage_datasource.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// Data boundary for local file pick/save. Catches picker/IO exceptions and
/// validates the picked file, returning a [RecoverBullFailure].
class FileSystemRepositoryImpl implements FileSystemRepository {
  final LogSink log;
  final FileStorageDatasource _fileStorageDataSource;

  FileSystemRepositoryImpl({
    required this.log,
    required FileStorageDatasource datasource,
  }) : _fileStorageDataSource = datasource;

  /// Picks a file and validates it is an encrypted vault. (Validation lives
  /// here, not in the use-case.)
  @override
  Future<Result<EncryptedVault, RecoverBullFailure>> pickVault() async {
    try {
      final file = await _fileStorageDataSource.pickFile();
      final fileContent = await file.readAsString();
      try {
        return Ok(EncryptedVaultMapper.parse(fileContent));
      } on Exception {
        return const Err(InvalidVaultFileFailure());
      }
    } on Exception catch (e, st) {
      log.error(
        'recoverbull.file.pick.unexpected error_type=${e.runtimeType}',
        trace: st,
      );
      return const Err(RecoverBullUnexpectedFailure('File operation failed'));
    }
  }

  @override
  Future<Result<Null, RecoverBullFailure>> saveVault(EncryptedVault vault) =>
      saveFile(EncryptedVaultMapper.fromEntity(vault).toFile(), vault.filename);

  @override
  Future<Result<Null, RecoverBullFailure>> saveFile(
    String content,
    String filename,
  ) async {
    try {
      await _fileStorageDataSource.saveFile(content, filename);
      return const Ok(null);
    } on Exception catch (e, st) {
      log.error(
        'recoverbull.file.save.unexpected error_type=${e.runtimeType}',
        trace: st,
      );
      return const Err(RecoverBullUnexpectedFailure('File operation failed'));
    }
  }
}
