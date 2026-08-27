import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';

abstract class LabelsRepositoryPort {
  Stream<void> get changes;

  Future<LabelEntity> store(NewLabel newLabel);

  Future<void> storeAll(List<NewLabel> labels);

  /// Restores labels without replacing a row that now occupies the same
  /// portable `(label, reference)` identity.
  Future<LabelRecoveryWriteResult> restoreMissing(List<NewLabel> labels);

  Future<List<LabelEntity>> fetchByLabel(String label);

  Future<List<LabelEntity>> fetchByReference(String reference);

  Future<LabelEntity?> fetchById(int id);

  Future<void> trash(int id);

  Future<List<LabelEntity>> fetchAll();
}

final class LabelRecoveryWriteResult {
  final int restoredCount;
  final int alreadyPresentCount;
  final int preservedLocalConflictCount;

  factory LabelRecoveryWriteResult({
    required int restoredCount,
    required int alreadyPresentCount,
    required int preservedLocalConflictCount,
  }) {
    if (restoredCount < 0 ||
        alreadyPresentCount < 0 ||
        preservedLocalConflictCount < 0) {
      throw ArgumentError('label recovery write counts are invalid');
    }
    return LabelRecoveryWriteResult._(
      restoredCount: restoredCount,
      alreadyPresentCount: alreadyPresentCount,
      preservedLocalConflictCount: preservedLocalConflictCount,
    );
  }

  const LabelRecoveryWriteResult._({
    required this.restoredCount,
    required this.alreadyPresentCount,
    required this.preservedLocalConflictCount,
  });

  int get intendedCount =>
      restoredCount + alreadyPresentCount + preservedLocalConflictCount;
}
