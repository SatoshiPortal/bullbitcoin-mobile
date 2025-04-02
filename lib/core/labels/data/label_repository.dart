import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';

class LabelRepository {
  final LabelStorageDatasource _labelStorageDatasource;

  LabelRepository({
    required LabelStorageDatasource labelStorageDatasource,
  }) : _labelStorageDatasource = labelStorageDatasource;

  Future<void> createLabel(Label label) async {
    await _labelStorageDatasource.create(label);
  }

  Future<List<Label>?> findLabelsByName(String labelText) async {
    final labelModels = await _labelStorageDatasource.readByLabel(labelText);
    if (labelModels == null || labelModels.isEmpty) {
      return null;
    }

    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<List<Label>?> findLabelsByRef(String ref) async {
    final labelModels = await _labelStorageDatasource.readByRef(ref);
    if (labelModels == null || labelModels.isEmpty) {
      return null;
    }

    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<void> deleteLabel(Label label) async {
    await _labelStorageDatasource.deleteLabel(label);
  }

  Future<List<Label>> getAllLabels() async {
    final labelModels = await _labelStorageDatasource.readAll();
    return labelModels.map((model) => model.toEntity()).toList();
  }
}
