import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';

abstract class LabelsRepositoryPort {
  Future<LabelEntity> store(NewLabel newLabel);

  Future<void> patch(LabelEntity label);

  Future<List<LabelEntity>> fetchByLabel(String label);

  Future<List<LabelEntity>> fetchByReference(String reference);

  Future<LabelEntity?> fetchById(int id);

  Future<void> trash(int id);

  Future<List<LabelEntity>> fetchAll();
}
