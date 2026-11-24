import 'package:backup_storage/backup_storage.dart' show BackupDestination;
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../repositories/backup_metadata_repository.dart';

final class ConfigureBackupUsecase {
  final BackupMetadataRepository _repository;

  const ConfigureBackupUsecase(this._repository);

  Future<Result<void, BackupMetadataFailure>> execute({
    required BackupDestination? destination,
    required Set<String> groups,
    bool deleteOwnedFiles = false,
  }) => _repository.configure(
    destination: destination,
    groups: groups,
    deleteOwnedFiles: deleteOwnedFiles,
  );
}
