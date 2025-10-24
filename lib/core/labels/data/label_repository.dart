import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';

class LabelRepository {
  final LabelDatasource _labelDatasource;

  LabelRepository({required LabelDatasource labelDatasource})
    : _labelDatasource = labelDatasource;

  Future<void> store(Label label) async {
    final model = LabelModel.fromEntity(label);

    await _labelDatasource.store(model);
  }

  Future<void> batch(List<Label> labels) async {
    final models = labels.map((label) => LabelModel.fromEntity(label)).toList();
    await _labelDatasource.batch(models);
  }

  Future<List<Label>> fetchByLabel(String label) async {
    final labelModels = await _labelDatasource.fetchByLabel(label: label);
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<void> trashByLabel(String label) async {
    await _labelDatasource.trashByLabel(label: label);
  }

  Future<void> trashLabel(Label label) async {
    final model = LabelModel.fromEntity(label);
    await _labelDatasource.trashLabel(model);
  }

  Future<List<Label>> fetchAll() async {
    final labelModels = await _labelDatasource.fetchAll();
    return labelModels.map((model) => model.toEntity()).toList();
  }

  Future<void> trashAll() async {
    await _labelDatasource.trashAll();
  }
}
