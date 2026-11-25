import 'package:labels/backup.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/discovered_backup.dart';
import '../entities/restore_report.dart';
import '../ports/backup_labels_port.dart';
import '../ports/backup_secrets_port.dart';

final class ApplyRestoreUsecase {
  final BackupLabelsPort _labels;
  final BackupSecretsPort _secrets;

  const ApplyRestoreUsecase(this._labels, this._secrets);

  /// Applies the Secrets part, then the Labels part, each only while the
  /// view of the discovery is still the active one. Both parts are
  /// idempotent, so an interruption between them is completed by running
  /// this again. Only when both fail is the result an error.
  Future<Result<RestoreReport, BackupMetadataFailure>> execute(
    DiscoveredBackup backup,
    MergePlan plan,
    MergeChoices choices,
  ) async {
    if (backup.group.ambiguous) {
      return const Err(BackupMetadataIncompatibleFailure());
    }
    if (!await _sameScope(backup)) {
      return const Err(BackupMetadataScopeChangedFailure());
    }
    final secrets = await _secrets.restore(backup.group, backup.content);
    if (!await _sameScope(backup)) {
      return const Err(BackupMetadataScopeChangedFailure());
    }
    final labels = await _labels.apply(plan, choices);
    if (secrets is Err<SecretsRestoreReport, BackupMetadataFailure> &&
        labels is Err<ApplyReport, BackupMetadataFailure>) {
      return Err(secrets.failure);
    }
    return Ok(
      RestoreReport(
        labels: labels is Ok<ApplyReport, BackupMetadataFailure>
            ? labels.value
            : null,
        labelsFailure: labels is Err<ApplyReport, BackupMetadataFailure>
            ? labels.failure
            : null,
        secrets: secrets is Ok<SecretsRestoreReport, BackupMetadataFailure>
            ? secrets.value
            : null,
        secretsFailure:
            secrets is Err<SecretsRestoreReport, BackupMetadataFailure>
            ? secrets.failure
            : null,
      ),
    );
  }

  Future<bool> _sameScope(DiscoveredBackup backup) async {
    final scope = await _secrets.viewScope();
    return scope is Ok<String, BackupMetadataFailure> &&
        scope.value == backup.scope;
  }
}
