import 'package:meta/meta.dart';
import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_inventory.dart';
import 'backup_secrets_port.dart';

/// Adapts the Labels owner's backup operations to the current inventory.
///
/// Every operation carries the session it belongs to: the adapter checks it
/// right after it re-reads the inventory and hands Labels a check to ask inside
/// its transaction and before each freeze.
abstract interface class BackupLabelsPort {
  /// Debounce hint only; correctness never depends on it.
  Stream<void> get changes;

  /// Labels of the group's wallets, freezes as `spendable`, read from their
  /// durable stores.
  @useResult
  Future<Result<LabelsSnapshot, BackupMetadataFailure>> capture(
    BackupSessionRef session,
    BackupGroup group,
  );

  @useResult
  Future<Result<MergePlan, BackupMetadataFailure>> preview(
    BackupSessionRef session,
    BackupGroup group,
    LabelsSnapshot incoming,
  );

  /// Checks freshness and writes labels in one transaction, then applies
  /// freezes through the ownership-checked path, one outpoint at a time.
  /// Idempotent: retrying only completes what is still missing.
  @useResult
  Future<Result<ApplyReport, BackupMetadataFailure>> apply(
    BackupSessionRef session,
    MergePlan plan,
    MergeChoices choices,
  );
}
