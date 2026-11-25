import 'package:labels/backup.dart';

import '../backup_metadata_failure.dart';
import '../ports/backup_secrets_port.dart';

/// What applying a backup did, owner by owner. One owner can fail while the
/// other succeeds: the result is partial, never hidden, and applying again
/// only completes what is missing.
final class RestoreReport {
  final ApplyReport? labels;
  final BackupMetadataFailure? labelsFailure;
  final SecretsRestoreReport? secrets;
  final BackupMetadataFailure? secretsFailure;

  const RestoreReport({
    this.labels,
    this.labelsFailure,
    this.secrets,
    this.secretsFailure,
  });

  bool get isPartial => labelsFailure != null || secretsFailure != null;
}
