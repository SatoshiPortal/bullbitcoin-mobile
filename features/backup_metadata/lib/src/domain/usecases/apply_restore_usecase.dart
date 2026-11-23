import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../ports/backup_labels_port.dart';

final class ApplyRestoreUsecase {
  final BackupLabelsPort _labels;

  const ApplyRestoreUsecase(this._labels);

  Future<Result<ApplyReport, BackupMetadataFailure>> execute(
    MergePlan plan,
    MergeChoices choices,
  ) => _labels.apply(plan, choices);
}
