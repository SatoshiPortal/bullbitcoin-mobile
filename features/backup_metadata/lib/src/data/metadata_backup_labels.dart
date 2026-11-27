import 'package:labels/backup.dart';
import 'package:labels/labels.dart' show LabelFailure;
import 'package:primitives/primitives.dart';

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_inventory.dart';
import '../domain/ports/backup_inventory_port.dart';
import '../domain/ports/backup_labels_port.dart';
import '../domain/ports/backup_secrets_port.dart';

final class MetadataBackupLabels implements BackupLabelsPort {
  final BackupInventoryPort _inventory;
  final LabelBackups _labels;

  MetadataBackupLabels({
    required this._inventory,
    required LabelBackups backups,
  }) : _labels = backups;

  @override
  Stream<void> get changes => _labels.changes;

  @override
  Future<Result<LabelsSnapshot, BackupMetadataFailure>> capture(
    BackupSessionRef session,
    BackupGroup group,
  ) => _withScope(session, group.id, _labels.capture);

  @override
  Future<Result<MergePlan, BackupMetadataFailure>> preview(
    BackupSessionRef session,
    BackupGroup group,
    LabelsSnapshot incoming,
  ) => _withScope(
    session,
    group.id,
    (scope) => _labels.preview(scope, incoming),
  );

  @override
  Future<Result<ApplyReport, BackupMetadataFailure>> apply(
    BackupSessionRef session,
    MergePlan plan,
    MergeChoices choices,
  ) => _withScope(
    session,
    plan.groupId,
    (scope) => _labels.apply(scope, plan, choices),
  );

  Future<Result<T, BackupMetadataFailure>> _withScope<T>(
    BackupSessionRef session,
    String groupId,
    Future<Result<T, LabelFailure>> Function(LabelBackupScope) operation,
  ) async {
    if (!session.isCurrent) {
      return const Err(BackupMetadataScopeChangedFailure());
    }
    final inventory = await _inventory.read();
    if (inventory case Err(:final failure)) return Err(failure);
    // The inventory was re-read, which took time: the session may have ended
    // between that read and the Labels transaction.
    if (!session.isCurrent) {
      return const Err(BackupMetadataScopeChangedFailure());
    }
    final groups =
        (inventory as Ok<BackupInventory, BackupMetadataFailure>).value.groups;
    final group = groups.where((group) => group.id == groupId).firstOrNull;
    if (group == null) return const Err(BackupMetadataStalePlanFailure());
    final scope = LabelBackupScope(
      groupId: groupId,
      bitcoinWalletIds: group.bitcoinWalletIds,
      liquidWalletIds: group.liquidWalletIds,
      authority: () => session.isCurrent,
      allWalletIds: [
        for (final group in groups) ...group.bitcoinWalletIds,
        for (final group in groups) ...group.liquidWalletIds,
      ],
    );
    return (await operation(scope)).mapErr(
      (failure) => switch (failure) {
        LabelBackupStalePlanFailure() => const BackupMetadataStalePlanFailure(),
        LabelBackupRevokedFailure() =>
          const BackupMetadataScopeChangedFailure(),
        _ => const BackupMetadataUnexpectedFailure(),
      },
    );
  }
}
