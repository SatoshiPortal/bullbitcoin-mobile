import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/new_label.dart';

abstract class LabelsRepositoryPort {
  Stream<void> get changes;

  Future<LabelEntity> store(NewLabel newLabel);

  Future<void> storeAll(List<NewLabel> labels);

  Future<List<LabelEntity>> fetchByLabel(String label);

  Future<List<LabelEntity>> fetchByReference(String reference);

  Future<LabelEntity?> fetchById(int id);

  Future<void> trash(int id);

  Future<List<LabelEntity>> fetchAll();
}
