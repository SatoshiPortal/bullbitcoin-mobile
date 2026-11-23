import 'package:labels/backup.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_inventory.dart';
import '../domain/ports/backup_inventory_port.dart';
import '../domain/ports/backup_labels_port.dart';

final class MetadataBackupLabels implements BackupLabelsPort {
  final BackupInventoryPort _inventory;
  final LabelBackups _labels;

  MetadataBackupLabels({required this._inventory, required Labels labels})
    : _labels = labels.backup;

  @override
  Stream<void> get changes => _labels.changes;

  @override
  Future<Result<LabelsSnapshot, BackupMetadataFailure>> capture(
    BackupGroup group,
  ) => _withScope(group.id, _labels.capture);

  @override
  Future<Result<MergePlan, BackupMetadataFailure>> preview(
    BackupGroup group,
    LabelsSnapshot incoming,
  ) => _withScope(group.id, (scope) => _labels.preview(scope, incoming));

  @override
  Future<Result<ApplyReport, BackupMetadataFailure>> apply(
    MergePlan plan,
    MergeChoices choices,
  ) => _withScope(plan.groupId, (scope) => _labels.apply(scope, plan, choices));

  Future<Result<T, BackupMetadataFailure>> _withScope<T>(
    String groupId,
    Future<Result<T, LabelFailure>> Function(LabelBackupScope) operation,
  ) async {
    final inventory = await _inventory.read();
    if (inventory case Err(:final failure)) return Err(failure);
    final groups =
        (inventory as Ok<BackupInventory, BackupMetadataFailure>).value.groups;
    final group = groups.where((group) => group.id == groupId).firstOrNull;
    if (group == null) return const Err(BackupMetadataStalePlanFailure());
    final scope = LabelBackupScope(
      groupId: groupId,
      bitcoinWalletIds: group.bitcoinWalletIds,
      liquidWalletIds: group.liquidWalletIds,
      allWalletIds: [
        for (final group in groups) ...group.bitcoinWalletIds,
        for (final group in groups) ...group.liquidWalletIds,
      ],
    );
    return (await operation(scope)).mapErr(
      (failure) => switch (failure) {
        LabelBackupStalePlanFailure() => const BackupMetadataStalePlanFailure(),
        _ => const BackupMetadataUnexpectedFailure(),
      },
    );
  }
}
