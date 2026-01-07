import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/labels/data/label_model.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';

class LabelRepository {
  final LabelsLocalDatasource _labelsLocalDatasource;

  LabelRepository({required LabelsLocalDatasource labelDatasource})
    : _labelsLocalDatasource = labelDatasource;

  Future<void> store(Label label) async {
    final model = LabelModel.fromEntity(label).toSqlite();
    await _labelsLocalDatasource.store([model]);
  }

  Future<void> batch(List<Label> labels) async {
    final models = labels
        .map((label) => LabelModel.fromEntity(label).toSqlite())
        .toList();
    await _labelsLocalDatasource.store(models);
  }

  Future<List<Label>> fetchByLabel(String label) async {
    final models = await _labelsLocalDatasource.fetchByLabel(label);
    return models
        .map((model) => LabelModel.fromSqlite(model).toEntity())
        .toList();
  }

  Future<void> trashByLabel(String label) async {
    await _labelsLocalDatasource.trashByLabel(label);
  }

  Future<void> trashLabel(Label label) async {
    final model = LabelModel.fromEntity(label);
    await _labelsLocalDatasource.trashByLabelAndRef(
      label: model.label,
      ref: model.ref,
    );
  }

  Future<List<Label>> fetchAll() async {
    final models = await _labelsLocalDatasource.fetchAll();
    return models
        .map((model) => LabelModel.fromSqlite(model).toEntity())
        .toList();
  }

  Future<List<String>> fetchDistinct() async {
    final models = await _labelsLocalDatasource.fetchDistinct();
    return models.map((model) => model).toList();
  }

  Future<void> trashAll() async => await _labelsLocalDatasource.trashAll();
}
