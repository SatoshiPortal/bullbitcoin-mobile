import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/discovered_backup.dart';
import '../ports/backup_labels_port.dart';

final class PreviewRestoreUsecase {
  final BackupLabelsPort _labels;

  const PreviewRestoreUsecase(this._labels);

  Future<Result<MergePlan, BackupMetadataFailure>> execute(
    DiscoveredBackup backup,
  ) => _labels.preview(backup.group, backup.snapshot);
}
