import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';

abstract class LabelsRepositoryPort {
  Future<LabelEntity> store(NewLabel newLabel);

  Future<List<LabelEntity>> fetchByLabel(String label);

  Future<List<LabelEntity>> fetchByReference(String reference);

  Future<LabelEntity?> fetchById(int id);

  Future<void> trash(int id);

  /// Strict reads fail on a corrupt row instead of omitting it from a backup.
  Future<List<LabelEntity>> fetchAll({bool strict = false});

  Future<void> storeAll(List<NewLabel> labels);
}
