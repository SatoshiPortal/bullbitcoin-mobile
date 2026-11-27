import 'package:backup_storage/backup_storage.dart' show BackupDestination;

import '../backup_metadata_failure.dart';
import 'backup_inventory.dart';

final class BackupRunStatus {
  final BackupDestination? destination;
  final List<BackupGroupStatus> groups;
  final List<UnsupportedWallet> unsupported;
  final int unattributedCount;

  /// The account the user confirmed, as the storage names it. Shown on the
  /// confirmation only; never logged.
  final String? account;

  /// Fields left out across the groups; the count only.
  int get excluded => groups.fold(0, (sum, group) => sum + group.excluded);

  const BackupRunStatus({
    required this.destination,
    required this.groups,
    required this.unsupported,
    required this.unattributedCount,
    this.account,
  });
}

final class BackupGroupStatus {
  final BackupGroup group;
  final bool included;
  final DateTime? lastDurableBackup;
  final bool previousVersionKept;
  final bool pendingChanges;
  final int skippedCount;

  /// Free-text fields left out because they looked like secret material.
  final int excluded;
  final BackupMetadataFailure? failure;
  final BackupActionReason? actionNeeded;

  const BackupGroupStatus({
    required this.group,
    required this.included,
    this.lastDurableBackup,
    this.previousVersionKept = false,
    this.pendingChanges = false,
    this.skippedCount = 0,
    this.excluded = 0,
    this.failure,
    this.actionNeeded,
  });
}

enum BackupActionReason {
  authorizationRequired,
  cancelled,
  permissionRevoked,
  quotaExceeded,
  unavailable,
  incompleteCapture,
  tooLarge,
  accountChanged,
  ambiguous,
  unexpected,
}
