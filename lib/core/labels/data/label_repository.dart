import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:bb_mobile/core/labels/domain/label_entity.dart';

class LabelRepository {
  final LabelStorageDatasource _labelStorageDatasource;

  LabelRepository({
    required LabelStorageDatasource labelStorageDatasource,
  }) : _labelStorageDatasource = labelStorageDatasource;

  Future<void> store(Label label) async {
    final labelModel = LabelModel.fromEntity(label);
    await _labelStorageDatasource.store(labelModel);
  }

  Future<List<Label>> fetchByName(String label) async {
    final labelModels = await _labelStorageDatasource.fetchByLabel(label);
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<List<Label>> findLabelByRef(String type, String ref) async {
    final prefix = Prefix.from(type);
    final labelModels =
        await _labelStorageDatasource.fetchByEntity(prefix, ref);
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<void> trash(Label label) async {
    final labelModel = LabelModel.fromEntity(label);
    await _labelStorageDatasource.trash(labelModel);
  }

  Future<List<Label>> fetchAll() async {
    final labelModels = await _labelStorageDatasource.fetchAll();
    return labelModels.map((model) => model.toEntity()).toList();
  }
}
