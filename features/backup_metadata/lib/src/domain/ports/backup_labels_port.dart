import 'package:meta/meta.dart';
import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_inventory.dart';

/// Adapts the Labels owner's backup operations to the current inventory.
abstract interface class BackupLabelsPort {
  /// Debounce hint only; correctness never depends on it.
  Stream<void> get changes;

  /// Labels of the group's wallets, freezes as `spendable`, read from their
  /// durable stores.
  @useResult
  Future<Result<LabelsSnapshot, BackupMetadataFailure>> capture(
    BackupGroup group,
  );

  @useResult
  Future<Result<MergePlan, BackupMetadataFailure>> preview(
    BackupGroup group,
    LabelsSnapshot incoming,
  );

  /// Checks freshness and writes labels in one transaction, then applies
  /// freezes through the ownership-checked path, one outpoint at a time.
  /// Idempotent: retrying only completes what is still missing.
  @useResult
  Future<Result<ApplyReport, BackupMetadataFailure>> apply(
    MergePlan plan,
    MergeChoices choices,
  );
}
