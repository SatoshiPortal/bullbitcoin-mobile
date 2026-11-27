import 'package:backup_storage/backup_storage.dart' show BackupDestination;
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_confirmation.dart';
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

  /// Grants the destination and returns what to confirm; selects nothing.
  Future<Result<BackupConfirmation, BackupMetadataFailure>> stage(
    BackupDestination destination,
    Set<String> groups,
  ) => _repository.stage(destination, groups);

  Future<Result<void, BackupMetadataFailure>> discardStaged() =>
      _repository.discardStaged();

  /// Turns on for [groups] only if [confirmation] still holds.
  Future<Result<void, BackupMetadataFailure>> include(
    Set<String> groups,
    BackupConfirmation confirmation,
  ) => _repository.include(groups, confirmation);
}
