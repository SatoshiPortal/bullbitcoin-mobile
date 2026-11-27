import 'package:backup_storage/backup_storage.dart' show BackupDestination;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_confirmation.dart';
import '../entities/backup_status.dart';
import '../entities/backup_summary.dart';
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

  /// Reads the journal only: whether the user turned the feature on in this
  /// view, and when a backup last became durable. It never touches storage.
  @useResult
  Future<Result<BackupSummary, BackupMetadataFailure>> summary();

  /// Grants a destination and asks the storage for the account, with the
  /// authorization the user gives. Nothing is selected: the result only
  /// describes what to confirm, and an interruption leaves nothing on.
  @useResult
  Future<Result<BackupConfirmation, BackupMetadataFailure>> stage(
    BackupDestination destination,
    Set<String> groups,
  );

  /// Drops a staged destination the user declined.
  @useResult
  Future<Result<void, BackupMetadataFailure>> discardStaged();

  /// Turns the feature on for [groups] in one conditional write, only if the
  /// single-use identifier, the destination, the account, the generation, the
  /// session and the exact groups of [confirmation] still hold. Otherwise
  /// nothing changes.
  @useResult
  Future<Result<void, BackupMetadataFailure>> include(
    Set<String> groups,
    BackupConfirmation confirmation,
  );

  @useResult
  Future<Result<void, BackupMetadataFailure>> configure({
    required BackupDestination? destination,
    required Set<String> groups,
    required bool deleteOwnedFiles,
  });
}
