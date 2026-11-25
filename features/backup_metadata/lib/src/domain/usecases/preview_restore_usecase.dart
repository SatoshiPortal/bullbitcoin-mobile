import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/discovered_backup.dart';
import '../ports/backup_labels_port.dart';
import '../ports/backup_secrets_port.dart';

final class PreviewRestoreUsecase {
  final BackupLabelsPort _labels;
  final BackupSecretsPort _secrets;

  const PreviewRestoreUsecase(this._labels, this._secrets);

  /// Nothing is shown for a backup discovered in another view.
  Future<Result<MergePlan, BackupMetadataFailure>> execute(
    DiscoveredBackup backup,
  ) async {
    if (backup.group.ambiguous) {
      return const Err(BackupMetadataIncompatibleFailure());
    }
    final scope = await _secrets.viewScope();
    if (scope is! Ok<String, BackupMetadataFailure> ||
        scope.value != backup.scope) {
      return const Err(BackupMetadataScopeChangedFailure());
    }
    return _labels.preview(backup.group, backup.content.labels);
  }
}
