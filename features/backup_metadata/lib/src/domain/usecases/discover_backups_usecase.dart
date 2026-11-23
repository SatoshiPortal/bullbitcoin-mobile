import 'package:backup_storage/backup_storage.dart' show BackupDestination;
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/discovered_backup.dart';
import '../repositories/backup_metadata_repository.dart';

final class DiscoverBackupsUsecase {
  final BackupMetadataRepository _repository;

  const DiscoverBackupsUsecase(this._repository);

  Future<Result<List<DiscoveredBackup>, BackupMetadataFailure>> execute(
    BackupDestination destination,
  ) => _repository.discover(destination);
}
