import 'package:bb_mobile/features/labels/domain/label_entity.dart';

abstract class LabelsRepositoryPort {
  Future<void> store(List<LabelEntity> labels);

  Future<List<LabelEntity>> fetchByLabel(String label);

  Future<List<LabelEntity>> fetchByReference(String reference);

  Future<void> trashLabel({required String label, required String reference});

  Future<List<LabelEntity>> fetchAll();
}
