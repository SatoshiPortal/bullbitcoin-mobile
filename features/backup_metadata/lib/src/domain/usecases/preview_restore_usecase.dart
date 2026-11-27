import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/discovered_backup.dart';
import '../ports/backup_labels_port.dart';

final class PreviewRestoreUsecase {
  final BackupLabelsPort _labels;

  const PreviewRestoreUsecase(this._labels);

  /// Nothing is shown for a backup of a session that ended, including one whose
  /// view was reopened since: the plan is checked again after it is computed,
  /// immediately before it is handed out.
  Future<Result<MergePlan, BackupMetadataFailure>> execute(
    DiscoveredBackup backup,
  ) async {
    if (backup.group.ambiguous) {
      return const Err(BackupMetadataIncompatibleFailure());
    }
    if (!backup.scope.isCurrent) {
      return const Err(BackupMetadataScopeChangedFailure());
    }
    final plan = await _labels.preview(
      backup.scope,
      backup.group,
      backup.content.labels,
    );
    if (!backup.scope.isCurrent) {
      return const Err(BackupMetadataScopeChangedFailure());
    }
    return plan;
  }
}
