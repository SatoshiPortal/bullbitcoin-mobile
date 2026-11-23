import 'package:backup_storage/backup_storage.dart' show BackupDestination;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_status.dart';
import '../entities/discovered_backup.dart';

abstract interface class BackupMetadataRepository {
  @useResult
  Future<Result<BackupRunStatus, BackupMetadataFailure>> run();

  @useResult
  Future<Result<BackupRunStatus, BackupMetadataFailure>> status();

  @useResult
  Future<Result<List<DiscoveredBackup>, BackupMetadataFailure>> discover(
    BackupDestination destination,
  );

  @useResult
  Future<Result<void, BackupMetadataFailure>> configure({
    required BackupDestination? destination,
    required Set<String> groups,
    required bool deleteOwnedFiles,
  });
}
